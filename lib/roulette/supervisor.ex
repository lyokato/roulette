defmodule Roulette.Supervisor do

  require Logger

  use Supervisor

  alias Roulette.AtomGenerator
  alias Roulette.ClusterChooser
  alias Roulette.ClusterSupervisor
  alias Roulette.Config
  alias Roulette.SubscriptionSupervisor

  @type role :: :both | :subscriber | :publisher

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    children(opts) |> Supervisor.init(strategy: :one_for_one)
  end

  defp children(opts) do

    role = Keyword.get(opts, :role, :both)

    ring = Config.get(:connection, :ring)

    if length(ring) == 0 do
      raise "<Roulette> you should prepare at least one host, check your :ring configuration."
    end

    ClusterChooser.Default.init(ring)

    enabled_roles = case role do
      :both       -> [:publisher, :subscriber]
      :publisher  -> [:publisher]
      :subscriber -> [:subscriber]
    end

    pool_size      = Config.get(:connection, :pool_size)
    retry_interval = Config.get(:connection, :retry_interval)
    ping_interval  = Config.get(:connection, :ping_interval)

    cluster_supervisors = enabled_roles |> Enum.flat_map(fn role ->

      ring |> Enum.map(fn target ->

       cluster_supervisor(role,
                          target,
                          pool_size,
                          retry_interval,
                          ping_interval)

      end)

    end)

    FastGlobal.put(:roulette_use_reserved_ring, false)

    if role != :publisher do

      reserved_ring = Config.get(:connection, :reserved_ring)

      if length(reserved_ring) > 0 do

        FastGlobal.put(:roulette_use_reserved_ring, true)

        ClusterChooser.Reserved.init(reserved_ring)


        reserved_cluster_supervisors =
          reserved_ring |> Enum.map(fn target ->

           cluster_supervisor(:subscriber,
                              target,
                              pool_size,
                              retry_interval,
                              ping_interval)

          end)

        [{SubscriptionSupervisor.Default, []},
         {SubscriptionSupervisor.Reserved, []}] ++
           cluster_supervisors ++ reserved_cluster_supervisors

      else

        [{SubscriptionSupervisor.Default, []}] ++ cluster_supervisors

      end
    else
      cluster_supervisors
    end

  end

  defp cluster_supervisor(role, target, pool_size, retry_interval, ping_interval) do

    {host, port} = Config.get_host_and_port(target)

    name = AtomGenerator.cluster_supervisor(role, host, port)
    pool = AtomGenerator.cluster_pool(role, host, port)

    {ClusterSupervisor,
      [name:           name,
       host:           host,
       port:           port,
       retry_interval: retry_interval,
       ping_interval:  ping_interval,
       pool_name:      pool,
       pool_size:      pool_size]}

  end

end
