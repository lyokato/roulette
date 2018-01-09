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
        {:noreply, %{state|gnat: gnat}}

      other ->
        Logger.error "<Roulett.Connection> failed to connect: #{inspect other}"
        Process.send_after(self(), :connect, state.reconection_interval)

    end
  end

  def handle_info({:EXIT, pid, _reason}, %{gnat: pid}=state) do
    Logger.error "<Roulette.Connection> seems to be disconnected, try to reconnect"
    Process.send_after(self(), :connect, state.retry_interval)
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

    %__MODULE__{
      host: host,
      port: port,
      gnat: nil,
      retry_interval: retry_interval
    }

  end

end
