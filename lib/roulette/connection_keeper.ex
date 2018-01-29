defmodule Roulette.ConnectionKeeper do

  require Logger

  use GenServer

  @spec connection(pid) :: {:ok, pid} | {:error, :not_found}
  def connection(pid) do
    GenServer.call(pid, :get_connection)
  end

  defstruct host: "",
            port: nil,
            gnat: nil,
            ping_interval: 0,
            retry_interval: 0

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Process.flag(:trap_exit, true)
    send self(), :connect
    {:ok, new(opts)}
  end

  def handle_info(:connect, state) do

    gnat_opts =
      Roulette.Config.merge_gnat_config(%{
        host: state.host,
        port: state.port
      })

    case Gnat.start_link(gnat_opts) do

      {:ok, gnat} ->
        Process.send_after(self(), :ping, state.ping_interval)
        {:noreply, %{state|gnat: gnat}}

      other ->
        Logger.error "<Roulett.Connection:#{inspect self()}> failed to connect - #{state.host}:#{state.port} #{inspect other}"
        Process.send_after(self(), :connect, state.retry_interval)
        {:noreply, %{state| gnat: nil}}

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
    Logger.error "<Roulette.Connection:#{inspect self()}> seems to be disconnected - #{state.host}:#{state.port}, try to reconnect"
    Process.send_after(self(), :connect, state.retry_interval)
    {:noreply, %{state| gnat: nil}}
  end
  def handle_info({:EXIT, _pid, _reason}, state) do
    {:noreply, %{state| gnat: nil}}
  end
  def handle_info(_info, state) do
    {:noreply, state}
  end

  def handle_call(:get_connection, _from, %{gnat: nil}=state) do
    {:reply, {:error, :not_found}, state}
  end
  def handle_call(:get_connection, _from, %{gnat: gnat}=state) do
    {:reply, {:ok, gnat}, state}
  end

  def terminate(_reason, _state), do: :ok

  defp new(opts) do

    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)

    retry_interval = Keyword.fetch!(opts, :retry_interval)
    ping_interval  = Keyword.fetch!(opts, :ping_interval)

    %__MODULE__{
      host: host,
      port: port,
      gnat: nil,
      ping_interval:  ping_interval,
      retry_interval: retry_interval
    }

  end

  defp do_gnat_ping(conn) do
    try do
      Gnat.ping(conn)
    catch
      # if it takes 5_000 milli seconds (5_000 is default setting for GenServer.call)
      :exit, e ->
        Logger.error "<Roulette.Connection:#{inspect self()}> failed to ping: #{inspect e}"
        {:error, :timeout}
    end
  end

end
