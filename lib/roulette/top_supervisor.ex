defmodule Roulette.TopSupervisor do

  require Logger

  use Supervisor

  alias Roulette.ClusterChooser
  alias Roulette.ClusterSupervisor
  alias Roulette.Config

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    children(opts)
    |> supervise(strategy: :one_for_one)
  end

  defp children(_opts) do

    hosts          = Config.get(:connection, :hosts)
    port           = Config.get(:connection, :port)
    pool_size      = Config.get(:connection, :pool_size)
    retry_interval = Config.get(:connection, :retry_interval)

    cluster_settings =
      hosts
      |> Enum.map(&(cluster_setting(&1, port, pool_size, retry_interval)))

    specs = cluster_settings |> Enum.map(fn {_, spec} -> spec end)
    pools = cluster_settings |> Enum.map(fn {pool, _} -> pool end)

    ClusterChooser.init(pools)

    specs
  end

  defp cluster_setting(host, port, pool_size, retry_interval) do
    name = Module.concat(Roulette.ClusterSupervisor, host)
    pool = Module.concat(Roulette.ClusterConnectionPool, host)

    {pool, supervisor(ClusterSupervisor, [
      [name:           name,
       host:           host,
       port:           port,
       retry_interval: retry_interval,
       pool_name:      pool,
       pool_size:      pool_size]
    ], [id: name])}
  end

end
