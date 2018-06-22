defmodule Roulette.Supervisor do

  require Logger

  use Supervisor

  alias Roulette.ClusterChooser
  alias Roulette.ClusterSupervisor
  alias Roulette.ClusterPool
  alias Roulette.Config
  alias Roulette.SubscriptionSupervisor
  alias Roulette.Registry

  @type role :: :both | :subscriber | :publisher

  def start_link(module, opts) do
    name = Module.concat(module, Supervisor)
    Supervisor.start_link(__MODULE__, [module, opts], name: name)
  end

  def init([module, opts]) do
    children(module, opts)
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp children(module, opts) do

    # check :role
    role = Keyword.get(opts, :role, :both)

    enabled_roles = case role do
      :both       -> [:publisher, :subscriber]
      :publisher  -> [:publisher]
      :subscriber -> [:subscriber]
    end

    connection_conf = Keyword.get(opts, :connection, [])

    # check :servers
    servers = Keyword.get(connection_conf, :servers)
    if length(servers) == 0 do
      raise "<Roulette> you should prepare at least one host, check your :servers configuration."
    end

    ClusterChooser.init(module, servers)

    cluster_supervisors =
      enabled_roles
      |> Enum.flat_map(fn role ->
        servers
        |> Enum.map(fn server ->
          cluster_supervisor(module, role, server, connection_conf)
        end)
      end)

    if role != :publisher do
      cluster_supervisors ++ [
        {Registry, [module]},
        {SubscriptionSupervisor, [module]}
      ]
    else
      cluster_supervisors
    end

  end

  defp cluster_supervisor(module, role, server, conf) do

    pool_size        = Keyword.get(conf, :pool_size)
    ping_interval    = Keyword.get(conf, :ping_interval)
    max_ping_failure = Keyword.get(conf, :max_ping_failure)
    show_debug_log   = Keyword.get(conf, :show_debug_log)

    {host, port} = Config.get_host_and_port(server)

    name = ClusterSupervisor.name(module, role, host, port)
    pool = ClusterPool.name(module, role, host, port)

    {ClusterSupervisor,
      [name:             name,
       host:             host,
       port:             port,
       ping_interval:    ping_interval,
       max_ping_failure: max_ping_failure,
       show_debug_log:   show_debug_log,
       pool_name:        pool,
       pool_size:        pool_size]}

  end

end
