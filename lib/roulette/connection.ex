defmodule Roulette.Connection do

  require Logger

  use GenServer

  @reconnection_interval 100

  @spec get(pid) :: {:ok, pid} | {:error, :not_found}
  def get(pid) do
    GenServer.call(pid, :get_connection)
  end

  defstruct host: "",
            port: nil,
            gnat: nil,
            show_debug_log: false,
            ping_interval: 0

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do

    Process.flag(:trap_exit, true)

    state = new(opts)

    send self(), :connect

    {:ok, state}

  end

  def handle_info(:connect, state) do

    gnat_opts =
      Roulette.Config.merge_gnat_config(%{
        host: state.host,
        port: state.port
      })

    if state.show_debug_log do
      Logger.debug "<Roulette.Connection:#{inspect self()}> CONNECT: #{inspect gnat_opts}"
    end

    case Gnat.start_link(gnat_opts) do

      {:ok, gnat} ->
        if state.show_debug_log do
          Logger.debug "<Roulette.Connection:#{inspect self()}> linked to gnat(#{inspect gnat})."
        end
        Process.send_after(self(), :ping, state.ping_interval)
        {:noreply, %{state|gnat: gnat}}

      other ->
        Logger.error "<Roulett.Connection:#{inspect self()}> failed to connect - #{state.host}:#{state.port} #{inspect other}"
        {:stop, :shutdown, state}

    end

  end

  def handle_info(:ping, state) do

    if state.gnat != nil do

      # send PING and wait for PONG
      case do_gnat_ping(state.gnat) do

        :ok ->
          # OK, got PONG in time. Check again after interval.
          Process.send_after(self(), :ping, state.ping_interval)

        _other ->
          # if it takes 3_000 milli seconds (3_000 is hard-coded in Gnat)
          Logger.warn "<Roulette.Connection:#{inspect self()}> failed PING. close connection."
          Gnat.stop(state.gnat)

      end

    end

    {:noreply, state}
  end

  def handle_info({:EXIT, pid, _reason}, %{gnat: pid}=state) do
    Logger.warn "<Roulette.Connection:#{inspect self()}> seems to be disconnected - gnat(#{inspect pid}:#{state.host}:#{state.port}), try to reconnect."
    Process.send_after(self(), :connect, @reconnection_interval)
    {:noreply, %{state| gnat: nil}}
  end
  def handle_info({:EXIT, pid, _reason}, state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Connection:#{inspect self()}> EXIT(#{inspect pid})"
    end
    {:stop, :shutdown, state}
  end
  def handle_info(info, state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Connection:#{inspect self()}> unsupported info: #{inspect info}"
    end
    {:noreply, state}
  end

  def handle_call(:get_connection, _from, %{gnat: nil}=state) do
    {:reply, {:error, :not_found}, state}
  end
  def handle_call(:get_connection, _from, %{gnat: gnat}=state) do
    {:reply, {:ok, gnat}, state}
  end

  def terminate(reason, %{gnat: nil}=state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Connection:#{inspect self()}> terminate: #{inspect reason}"
    end
    :ok
  end
  def terminate(reason, %{gnat: gnat}=state) do
    if state.show_debug_log do
      Logger.debug "<Roulette.Connection:#{inspect self()}> terminate: #{inspect reason}"
      Logger.debug "<Roulette.Connection:#{inspect self()}> stop gnat"
    end
    Gnat.stop(gnat)
    :ok
  end

  defp new(opts) do

    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)

    ping_interval   = Keyword.fetch!(opts, :ping_interval)
    show_debug_log  = Keyword.fetch!(opts, :show_debug_log)

    %__MODULE__{
      host: host,
      port: port,
      gnat: nil,
      show_debug_log: show_debug_log,
      ping_interval:  ping_interval,
    }

  end

  defp do_gnat_ping(conn) do
    try do
      Gnat.ping(conn)
    catch
      # if it takes 5_000 milli seconds (5_000 is default setting for GenServer.call)
      :exit, e ->
        Logger.error "<Roulette.Connection:#{inspect self()}> failed to PING: #{inspect e}"
        {:error, :timeout}
    end
  end

end
