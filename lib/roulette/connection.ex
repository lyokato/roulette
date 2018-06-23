defmodule Roulette.Connection do

  require Logger

  use GenServer

  alias Roulette.Config
  alias Roulette.NatsClient

  @reconnection_interval 100

  @spec get(pid) :: {:ok, pid} | {:error, :not_found | :timeout}
  def get(pid) do
    try do
      GenServer.call(pid, :get_connection, 50)
    catch
      :exit, _e ->
        {:error, :timeout}
    end
  end

  defstruct host:             "",
            module:           nil,
            port:             nil,
            nats:             nil,
            show_debug_log:   false,
            ping_count:       0,
            max_ping_failure: 2,
            ping_interval:    0

  @spec start_link(Keyword.t) :: GenServer.on_start
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)
    state = new(opts)
    send self(), :connect
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:connect, state) do

    nats_opts =
      Config.merge_nats_config(state.module, %{
        host: state.host,
        port: state.port
      })

    Logger.debug fn ->
      if state.show_debug_log do
        "<Roulette.Connection:#{inspect self()}> CONNECT: #{inspect nats_opts}"
      end
    end

    case NatsClient.start_link(nats_opts) do

      {:ok, nats} ->
        Logger.debug fn ->
          if state.show_debug_log do
            "<Roulette.Connection:#{inspect self()}> linked to nats(#{inspect nats})."
          end
        end
        Process.send_after(self(), :ping, calc_ping_interval(state.ping_interval))
        {:noreply, %{state|nats: nats, ping_count: 0}}

      other ->
        Logger.error "<Roulett.Connection:#{inspect self()}> failed to connect - #{state.host}:#{state.port} #{inspect other}"
        {:stop, :shutdown, state}

    end

  end

  def handle_info(:pong, state) do
    {:noreply, %{state|ping_count: 0}}
  end

  def handle_info(:ping, %{nats: nil} = state) do
    {:noreply, state}
  end
  def handle_info(:ping, state) do

    if state.ping_count >= state.max_ping_failure do

      Logger.error "<Roulette.Connection:#{inspect self()}> failed #{state.max_ping_failure} PING(s). close connection. host: #{state.host}"
      NatsClient.stop(state.nats)
      {:noreply, %{state|ping_count: 0}}

    else

      if state.ping_count > 0 do
        Logger.warn "<Roulette.Connection:#{inspect self()}> failed #{state.ping_count} PING(s). keep waiting. host: #{state.host}"
      end

      case do_nats_ping(state.nats) do

        :ok ->
          # OK, got PONG in time. Check again after interval.
          Process.send_after(self(), :ping, calc_ping_interval(state.ping_interval))
          ping_count = state.ping_count + 1
          {:noreply, %{state|ping_count: ping_count}}

        other ->
          Logger.warn "<Roulette.Connection:#{inspect self()}> failed PING. close connection. #{inspect other}. host: #{state.host}"
          NatsClient.stop(state.nats)
          {:noreply, state}

      end

    end
  end

  def handle_info({:EXIT, pid, _reason}, %{nats: pid} = state) do
    Logger.warn "<Roulette.Connection:#{inspect self()}> seems to be disconnected - nats(#{inspect pid}:#{state.host}:#{state.port}), try to reconnect."
    Process.send_after(self(), :connect, @reconnection_interval)
    {:noreply, %{state| nats: nil}}
  end
  def handle_info({:EXIT, pid, _reason}, state) do
    Logger.debug fn ->
      if state.show_debug_log do
        "<Roulette.Connection:#{inspect self()}> EXIT(#{inspect pid})"
      end
    end
    {:stop, :shutdown, state}
  end
  def handle_info(info, state) do
    Logger.debug fn ->
      if state.show_debug_log do
        "<Roulette.Connection:#{inspect self()}> unsupported info: #{inspect info}"
      end
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_connection, _from, %{nats: nil} = state) do
    {:reply, {:error, :not_found}, state}
  end
  def handle_call(:get_connection, _from, %{nats: nats} = state) do
    {:reply, {:ok, nats}, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.debug fn ->
      if state.show_debug_log do
        "<Roulette.Connection:#{inspect self()}> terminate: #{inspect reason}"
      end
    end
    :ok
  end

  defp new(opts) do

    host             = Keyword.fetch!(opts, :host)
    port             = Keyword.fetch!(opts, :port)
    module           = Keyword.fetch!(opts, :module)
    ping_interval    = Keyword.fetch!(opts, :ping_interval)
    show_debug_log   = Keyword.fetch!(opts, :show_debug_log)
    max_ping_failure = Keyword.fetch!(opts, :max_ping_failure)

    %__MODULE__{
      host:             host,
      port:             port,
      nats:             nil,
      module:           module,
      show_debug_log:   show_debug_log,
      ping_interval:    ping_interval,
      max_ping_failure: max_ping_failure,
      ping_count:       0,
    }

  end

  defp calc_ping_interval(interval) do
    # TODO make configurable
    interval + :rand.uniform(1000)
  end

  defp do_nats_ping(conn) do
    try do
      NatsClient.ping(conn)
    catch
      # if it takes 5_000 milli seconds (5_000 is default setting for GenServer.call)
      :exit, e ->
        Logger.error "<Roulette.Connection:#{inspect self()}> failed to PING: #{inspect e}"
        {:error, :timeout}
    end
  end

end
