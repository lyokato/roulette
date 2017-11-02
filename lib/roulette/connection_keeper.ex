defmodule Roulette.ConnectionKeeper do

  @default_port 6379
  @default_reconnection_interval 5_000

  require Logger

  use GenServer

  @spec connection(pid) :: {:ok, pid} | {:error, :not_found}
  def connection(pid) do
    GenServer.call(pid, :get_connection)
  end

  defstruct host: "",
            port: nil,
            gnat: nil,
            reconnection_interval: 0

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Process.flag(:trap_exit, true)
    send self(), :connect
    {:ok, new(opts)}
  end

  def handle_info(:connect, %{}=state) do

    # TODO
    gnat_opts = %{}
    case Gnat.start_link(gnat_opts) do

      {:ok, gnat} ->
        # TODO start ping timer
        {:noreply, %{state|gnat: gnat}}

      other ->
        Logger.error "<Roulett.Connection> failed to connect: #{inspect other}"
        Process.send_after(self(), :connect, state.reconection_interval)

    end
  end

  def handle_info({:EXIT, pid, _reason}, %{gnat: pid}=state) do
    Logger.error "<Roulette.Connection> seems to be disconnected, try to re-connect"
    Process.send_after(self(), :connect, state.reconnection_interval)
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
    port = Keyword.get(opts, :port, @default_port)
    reconnection_interval = Keyword.get(opts, :reconnection_interval, @default_reconnection_interval)

    %__MODULE__{host: host,
                port: port,
                redix: nil,
                reconnection_interval: reconnection_interval}
  end

end
