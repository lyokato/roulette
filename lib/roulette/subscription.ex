defmodule Roulette.Subscription do

  require Logger

  use GenServer

  alias Roulette.Connection
  alias Roulette.Config
  alias Roulette.NatsClient
  alias Roulette.Util

  @type restart_strategy :: :temporary | :permanent
  @type ring_type :: :default | :reserved

  @checkout_timeout 5_100

  defstruct topic: "",
            ring_type: :default,
            consumer: nil,
            show_debug_log: false,
            restart: :permanent,
            pool: nil,
            nats: nil,
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

    start_setup()

    {:ok, state}

  end

  def handle_info({:setup, attempts, max_retry}, state) do
    setup(state, attempts, max_retry)
  end

  def handle_info({:DOWN, monitor_ref, :process, pid, _reason}, %{nats: pid, restart: :temporary}=state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Subscription:#{inspect self()}> DOWN(nats:#{inspect pid}) start to shutdown"
    end
    Process.demonitor(monitor_ref)
    {:stop, :shutdown, %{state| nats: nil, ref: nil}}
  end
  def handle_info({:DOWN, monitor_ref, :process, pid, _reason}, %{nats: pid, restart: :permanent}=state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Subscription:#{inspect self()}> DOWN(nats:#{inspect pid}) start to reconnect"
    end
    Process.demonitor(monitor_ref)
    start_setup()
    {:noreply, %{state| nats: nil, ref: nil}}
  end

  def handle_info({:DOWN, monitor_ref, :process, pid, _reason}, %{consumer: pid}=state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Subscription:#{inspect self()}> DOWN(consumer:#{inspect pid})"
    end
    Process.demonitor(monitor_ref)
    {:stop, :shutdown, state}
  end

  def handle_info({:msg, %{body: data, topic: _topic, reply_to: _reply_to}}, state) do
    send state.consumer, {:pubsub_message, state.topic, data, self()}
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, _reason}, %{consumer: pid}=state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Subscription:#{inspect self()}> EXIT(consumer:#{inspect pid})"
    end
    {:stop, :shutdown, state}
  end
  def handle_info({:EXIT, pid, _reason}, state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Subscription:#{inspect self()}> EXIT(#{inspect pid})"
    end
    {:stop, :shutdown, state}
  end

  def handle_info(info, state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Subscription:#{inspect self()}> unsupported info: #{inspect info}"
    end
    {:noreply, state}
  end

  def terminate(_reason, %{ref: nil}=state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Subscription:#{inspect self()}> terminate: #{inspect state}"
    end
    :ok
  end
  def terminate(_reason, state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Subscription:#{inspect self()}> terminate: #{inspect state}"
    end
    do_nats_unsub(state.nats, state.ref)
    :ok
  end

  defp new(opts) do
    %__MODULE__{
      pool:           opts.pool,
      consumer:       opts.consumer,
      topic:          opts.topic,
      ring_type:      opts.ring_type,
      ref:            nil,
      nats:           nil,
      restart:        Config.get(:subscriber, :restart),
      show_debug_log: Config.get(:subscriber, :show_debug_log),
    }
  end

  defp setup(state, attempts, max_retry) do

    case do_setup(state) do

      {:ok, nats, ref} ->
        Process.monitor(nats)
        {:noreply, %{state | ref: ref, nats: nats}}

      _other when attempts < max_retry ->
        retry_setup(attempts, max_retry)
        {:noreply, state}

      _other ->
        Logger.error "<Roulette.Subscription:#{inspect self()}> failed to setup subscription eventually"
        {:stop, :shutdown, state}
    end

  end

  defp do_setup(state) do
    try do
      :poolboy.transaction(state.pool, fn conn ->

        case Connection.get(conn) do

          {:ok, nats} ->
            case do_nats_sub(nats, state.topic) do
              {:ok, ref}       -> {:ok, nats, ref}
              {:error ,reason} -> {:error, reason}
            end

          {:error, :timeout} ->
            Logger.warn "<Roulette.Subscription:#{inspect self()}> failed checkout connection: timeout (maybe closing)"
            {:error, :timeout}

          {:error, :not_found} ->
            Logger.warn "<Roulette.Subscription:#{inspect self()}> connection lost"
            {:error, :not_found}

        end

      end, @checkout_timeout)
    catch
      :exit, _e ->
        Logger.warn "<Roulette.Subscription:#{inspect self()}> failed checkout connection: timeout"
        {:error, :timeout}
    end
  end

  defp do_nats_sub(nats, topic) do
    try do
      NatsClient.sub(nats, self(), topic)
    catch
      # if it takes 5_000 milli seconds (5_000 is default setting for GenServer.call)
      :exit, e ->
        Logger.error "<Roulette.Subscription:#{inspect self()}> failed to subscribe: #{inspect e}"
        {:error, :timeout}
    end
  end

  defp do_nats_unsub(nats, ref) do
    try do
      NatsClient.unsub(nats, ref)
    catch
      #:exit, {reason, _detail} = error when reason in [:shutdonw, :noproc] ->
      #  Logger.info "<Roulette.Subscription:#{inspect self()}> tried to unsub, but the connection is already closing: #{inspect error}"
      #  :ok

      # if it takes 5_000 milli seconds (5_000 is default setting for GenServer.call)
      :exit, e ->
        Logger.error "<Roulette.Subscription:#{inspect self()}> failed to unsubscribe: #{inspect e}"
        {:error, :timeout}
    end
  end

  defp start_setup() do
    attempts  = 0
    max_retry = Config.get(:subscriber, :max_retry)
    send self(), {:setup, attempts, max_retry}
  end

  defp retry_setup(attempts, max_retry) do
    message = {:setup, attempts + 1, max_retry}
    backoff = calc_backoff(attempts)
    Process.send_after(self(), message, backoff)
  end

  defp calc_backoff(attempts) do
    base = Config.get(:subscriber, :base_backoff)
    max  = Config.get(:subscriber, :max_backoff)
    Util.calc_backoff(base, max, attempts)
  end

end
