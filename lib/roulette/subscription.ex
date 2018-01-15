defmodule Roulette.Subscription do

  require Logger

  use GenServer

  alias Roulette.ConnectionKeeper
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
    {:stop, :shutdown, %{state| gnat: nil, ref: nil}}
  end
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{gnat: pid, restart: :permanent}=state) do
    Process.send_after(self(), :setup, state.retry_interval)
    {:noreply, %{state| gnat: nil, ref: nil}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{consumer: pid}=state) do
    {:stop, :shutdown, state}
  end

  def handle_info({:msg, %{body: data, topic: _topic, reply_to: _reply_to}}, state) do
    send state.consumer, {:pubsub_message, state.topic, data, self()}
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, _reason}, %{consumer: pid}=state) do
    {:stop, :shutdown, state}
  end
  def handle_info({:EXIT, _pid, _reason}, state) do
    {:stop, :shutdown, state}
  end

  def terminate(_reason, %{ref: nil}) do
    :ok
  end
  def terminate(_reason, state) do
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

  defp setup(state, retry_count, max_retry) do

    state.pool |> :poolboy.transaction(fn conn_keeper ->

      case ConnectionKeeper.connection(conn_keeper) do

        {:ok, conn} ->
          case do_gnat_sub(conn, state.topic) do

            {:ok, ref} ->
              Process.monitor(conn)
              {:noreply, %{state | ref: ref, gnat: conn}}

            other when retry_count < max_retry ->
              Logger.error "<Roulette.Subscription:#{inspect self()}> failed to subscribe on gnat: #{inspect other}"
              setup(state, retry_count + 1, max_retry)

            other ->
              Logger.error "<Roulette.Subscription:#{inspect self()}> failed to subscribe on gnat: #{inspect other}"
              {:stop, :shutdown, state}

          end

        {:error, :disconnected} when retry_count < max_retry ->
          Logger.error "<Roulette.Subscription:#{inspect self()}> couldn't checkout gnat connection"
          setup(state, retry_count + 1, max_retry)

        {:error, :disconnected} ->
          Logger.error "<Roulette.Subscription:#{inspect self()}> couldn't checkout gnat connection"
          {:stop, :shutdown, state}

      end

    end)

  end

  defp do_gnat_sub(conn, topic) do
    try do
      Gnat.sub(conn, self(), topic)
    catch
      :exit, e ->
        Logger.error "<Roulette.Subscription:#{inspect self()}> failed to subscribe: #{inspect e}"
        {:error, :timeout}
    end
  end

  defp do_gnat_unsub(conn, ref) do
    try do
      Gnat.unsub(conn, ref)
    catch
      :exit, e ->
        Logger.error "<Roulette.Subscription:#{inspect self()}> failed to unsubscribe: #{inspect e}"
        {:error, :timeout}
    end
  end


end
