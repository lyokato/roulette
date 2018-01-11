defmodule Roulette.Supervisor do

  require Logger

  use Supervisor

  alias Roulette.AtomGenerator
  alias Roulette.ClusterChooser
  alias Roulette.ClusterSupervisor
  alias Roulette.Config
  alias Roulette.SubscriptionSupervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(opts) do
    children(opts) |> Supervisor.init(strategy: :one_for_one)
  end

  defp children(_opts) do

    hosts = Config.get(:connection, :hosts)

    if length(hosts) == 0 do
      raise "<Roulette> you should prepare at least one host, check your configuration."
    end

    ClusterChooser.init(hosts)

    enabled_roles = [:publisher, :subscriber] |> Enum.filter(&(Config.get(&1, :enabled)))

    if length(enabled_roles) == 0 do
      raise "<Roulette> both :publisher and :subscriber are not enabled, check your configuration."
    end

    port           = Config.get(:connection, :port)
    pool_size      = Config.get(:connection, :pool_size)
    retry_interval = Config.get(:connection, :retry_interval)

    cluster_supervisors = enabled_roles |> Enum.flat_map(fn role ->

      hosts |> Enum.map(fn host ->

       cluster_supervisor(role,
                          host,
                          port,
                          pool_size,
                          retry_interval)

      end)

    end)

    if Config.get(:subscriber, :enabled) do
      [{SubscriptionSupervisor, []}] ++ cluster_supervisors
    else
      cluster_supervisors
    end

  end

  defp cluster_supervisor(role, host, port, pool_size, retry_interval) do

    name = AtomGenerator.cluster_supervisor(role, host)
    pool = AtomGenerator.cluster_pool(role, host)

    {ClusterSupervisor,
      [name:           name,
       host:           host,
       port:           port,
       retry_interval: retry_interval,
       pool_name:      pool,
       pool_size:      pool_size]}

  end

end
