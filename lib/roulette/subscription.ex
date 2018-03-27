defmodule Roulette.Subscription do

  require Logger

  use GenServer

  alias Roulette.Connection
  alias Roulette.Config

  @type restart_strategy :: :temporary | :permanent
  @type ring_type :: :default | :reserved

  defstruct topic: "",
            ring_type: :default,
            consumer: nil,
            retry_interval: 2_000,
            restart: :permanent,
            max_retry: 5,
            pool: nil,
            gnat: nil,
            ref: nil

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      restart: :temporary
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do

    Process.flag(:trap_exit, true)

    state = new(opts)

    :gproc.reg({:n, :l, {state.consumer, state.topic, state.ring_type}})

    if state.restart == :temporary do
      Process.link(state.consumer)
    else
      Process.monitor(state.consumer)
    end

    send self(), :setup

    {:ok, state}

  end

  def handle_info(:setup, state), do: setup(state, 0, state.max_retry)

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{gnat: pid, restart: :temporary}=state) do
    Logger.info "<Roulette.Subscription:#{inspect self()}> DOWN(gnat:#{inspect pid}) start to shutdown"
    {:stop, :shutdown, %{state| gnat: nil, ref: nil}}
  end
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{gnat: pid, restart: :permanent}=state) do
    Logger.info "<Roulette.Subscription:#{inspect self()}> DOWN(gnat:#{inspect pid}) start to reconnect"
    Process.send_after(self(), :setup, state.retry_interval)
    {:noreply, %{state| gnat: nil, ref: nil}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{consumer: pid}=state) do
    Logger.info "<Roulette.Subscription:#{inspect self()}> DOWN(consumer:#{inspect pid})"
    {:stop, :shutdown, state}
  end

  def handle_info({:msg, %{body: data, topic: _topic, reply_to: _reply_to}}, state) do
    send state.consumer, {:pubsub_message, state.topic, data, self()}
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, _reason}, %{consumer: pid}=state) do
    Logger.info "<Roulette.Subscription:#{inspect self()}> EXIT(consumer:#{inspect pid})"
    {:stop, :shutdown, state}
  end
  def handle_info({:EXIT, pid, _reason}, state) do
    Logger.info "<Roulette.Subscription:#{inspect self()}> EXIT(#{inspect pid})"
    {:stop, :shutdown, state}
  end

  def handle_info(info, state) do
    Logger.info "<Roulette.Subscription:#{inspect self()}> unsupported info: #{inspect info}"
    {:noreply, state}
  end

  def terminate(_reason, %{ref: nil}=state) do
    Logger.debug "<Roulette.Subscription:#{inspect self()}> terminate: #{inspect state}"
    :ok
  end
  def terminate(_reason, state) do
    Logger.debug "<Roulette.Subscription:#{inspect self()}> terminate: #{inspect state}"
    do_gnat_unsub(state.gnat, state.ref)
    :ok
  end

  defp new(opts) do
    %__MODULE__{
      pool:           opts.pool,
      consumer:       opts.consumer,
      topic:          opts.topic,
      ring_type:      opts.ring_type,
      restart:        Config.get(:subscriber, :restart),
      retry_interval: Config.get(:subscriber, :retry_interval),
      max_retry:      Config.get(:subscriber, :max_retry),
      ref:            nil,
      gnat:           nil
    }
  end

  defp setup(state, attempts, max_retry) do

    case do_setup(state) do

      {:ok, gnat, ref} ->
        Process.monitor(gnat)
        {:noreply, %{state | ref: ref, gnat: gnat}}

      other when attempts < max_retry ->
        Logger.error "<Roulette.Subscription:#{inspect self()}> failed to setup subscription: #{inspect other}"
        setup(state, attempts + 1, max_retry)

      other ->
        Logger.error "<Roulette.Subscription:#{inspect self()}> failed to setup subscription: #{inspect other}"
        {:stop, :shutdown, state}
    end

  end

  defp do_setup(state) do

    state.pool |> :poolboy.transaction(fn conn ->

      case Connection.get(conn) do

        {:ok, gnat} ->
          case do_gnat_sub(gnat, state.topic) do
            {:ok, ref}       -> {:ok, gnat, ref}
            {:error ,reason} -> {:error, reason}
          end

        {:error, :not_found} -> {:error, :not_found}

      end

    end)

  end

  defp do_gnat_sub(gnat, topic) do
    try do
      Gnat.sub(gnat, self(), topic)
    catch
      # if it takes 5_000 milli seconds (5_000 is default setting for GenServer.call)
      :exit, e ->
        Logger.error "<Roulette.Subscription:#{inspect self()}> failed to subscribe: #{inspect e}"
        {:error, :timeout}
    end
  end

  defp do_gnat_unsub(gnat, ref) do
    try do
      Gnat.unsub(gnat, ref)
    catch
      # if it takes 5_000 milli seconds (5_000 is default setting for GenServer.call)
      :exit, e ->
        Logger.error "<Roulette.Subscription:#{inspect self()}> failed to unsubscribe: #{inspect e}"
        {:error, :timeout}
    end
  end

end
