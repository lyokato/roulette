defmodule Roulette.Subscription do

  require Logger

  use GenServer

  alias Roulette.ClusterPool
  alias Roulette.Connection
  alias Roulette.Config
  alias Roulette.NatsClient
  alias Roulette.Registry
  alias Roulette.Util.Backoff

  @type restart_strategy :: :temporary
                         |  :permanent

  @checkout_timeout 5_100

  defstruct topic:          "",
            module:         nil,
            consumer:       nil,
            show_debug_log: false,
            restart:        :permanent,
            nats:           nil,
            ref:            nil

  @spec start_link(Keyword.t) :: GenServer.on_start
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do

    state = new(opts)

    Process.flag(:trap_exit, true)

    Registry.register(
      state.module,
      state.consumer,
      state.topic
    )

    if state.restart == :temporary do
      Process.link(state.consumer)
    else
      Process.monitor(state.consumer)
    end

    start_setup(state)

    {:ok, state}

  end

  @impl GenServer
  def handle_info({:setup, attempts, max_retry}, state) do
    setup(state, attempts, max_retry)
  end

  def handle_info({:DOWN, monitor_ref, :process, pid, _reason}, %{nats: pid, restart: :temporary} = state) do
    if state.show_debug_log do
      Logger.debug fn ->
        "<Roulette.Subscription:#{inspect self()}> DOWN(nats:#{inspect pid}) start to shutdown"
      end
    end
    Process.demonitor(monitor_ref)
    {:stop, :shutdown, %{state| nats: nil, ref: nil}}
  end
  def handle_info({:DOWN, monitor_ref, :process, pid, _reason}, %{nats: pid, restart: :permanent} = state) do
    if state.show_debug_log do
      Logger.debug fn ->
        "<Roulette.Subscription:#{inspect self()}> DOWN(nats:#{inspect pid}) start to reconnect"
      end
    end
    Process.demonitor(monitor_ref)
    start_setup(state)
    {:noreply, %{state| nats: nil, ref: nil}}
  end

  def handle_info({:DOWN, monitor_ref, :process, pid, _reason}, %{consumer: pid} = state) do
    if state.show_debug_log do
      Logger.debug fn ->
        "<Roulette.Subscription:#{inspect self()}> DOWN(consumer:#{inspect pid})"
      end
    end
    Process.demonitor(monitor_ref)
    {:stop, :shutdown, state}
  end

  def handle_info({:msg, %{body: data, topic: _topic, reply_to: _reply_to}}, state) do
    send state.consumer, {:pubsub_message, state.topic, data, self()}
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, _reason}, %{consumer: pid} = state) do
    if state.show_debug_log do
      Logger.debug fn ->
        "<Roulette.Subscription:#{inspect self()}> EXIT(consumer:#{inspect pid})"
      end
    end
    {:stop, :shutdown, state}
  end
  def handle_info({:EXIT, pid, _reason}, state) do
    if state.show_debug_log do
      Logger.debug fn ->
        "<Roulette.Subscription:#{inspect self()}> EXIT(#{inspect pid})"
      end
    end
    {:stop, :shutdown, state}
  end

  def handle_info(info, state) do
    if state.show_debug_log do
      Logger.debug fn ->
        "<Roulette.Subscription:#{inspect self()}> unsupported info: #{inspect info}"
      end
    end
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %{ref: nil} = state) do
    if state.show_debug_log do
      Logger.debug fn ->
        "<Roulette.Subscription:#{inspect self()}> terminate: #{inspect state}"
      end
    end
    :ok
  end
  def terminate(_reason, state) do
    if state.show_debug_log do
      Logger.debug fn ->
        "<Roulette.Subscription:#{inspect self()}> terminate: #{inspect state}"
      end
    end
    do_nats_unsub(state.nats, state.ref)
    :ok
  end

  defp new(opts) do

    consumer = Keyword.fetch!(opts, :consumer)
    topic    = Keyword.fetch!(opts, :topic)
    module   = Keyword.fetch!(opts, :module)

    %__MODULE__{
      consumer:       consumer,
      topic:          topic,
      module:         module,
      ref:            nil,
      nats:           nil,
      restart:        Config.get(module, :subscriber, :restart),
      show_debug_log: Config.get(module, :subscriber, :show_debug_log),
    }
  end

  defp setup(state, attempts, max_retry) do

    case do_setup(state) do

      {:ok, nats, ref} ->
        Process.monitor(nats)
        if state.show_debug_log do
          Logger.debug fn ->
            "<Roulette.Subscription:#{inspect self()}> start subscription on #{state.topic}"
          end
        end
        {:noreply, %{state | ref: ref, nats: nats}}

      _other when attempts < max_retry ->
        retry_setup(state.module, attempts, max_retry)
        {:noreply, state}

      _other ->
        Logger.error "<Roulette.Subscription:#{inspect self()}> failed to setup subscription eventually"
        {:stop, :shutdown, state}
    end

  end

  defp choose_pool(state) do
    ClusterPool.choose(state.module, :subscriber, state.topic)
  end

  defp do_setup(state) do
    try do
      state
      |> choose_pool()
      |> :poolboy.transaction(fn conn ->

        case Connection.get(conn) do

          {:ok, nats} ->
            case do_nats_sub(nats, state.topic) do
              {:ok, ref}       -> {:ok, nats, ref}
              {:error, reason} -> {:error, reason}
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

  defp start_setup(state) do
    attempts  = 0
    max_retry = Config.get(state.module, :subscriber, :max_retry)
    send self(), {:setup, attempts, max_retry}
  end

  defp retry_setup(module, attempts, max_retry) do
    message = {:setup, attempts + 1, max_retry}
    backoff = calc_backoff(attempts, module)
    Process.send_after(self(), message, backoff)
    :ok
  end

  defp calc_backoff(attempts, module) do
    Backoff.calc(module, :subscriber, attempts)
  end

end
