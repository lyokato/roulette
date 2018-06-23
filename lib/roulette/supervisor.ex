defmodule Roulette.Supervisor do

  use Supervisor

  alias Roulette.ClusterChooser
  alias Roulette.ClusterSupervisor
  alias Roulette.ClusterPool
  alias Roulette.Config
  alias Roulette.SubscriptionSupervisor

  @type role :: :both | :subscriber | :publisher

  def start_link([module, conf, opts]) do
    name = Module.concat(module, Supervisor)
    Supervisor.start_link(__MODULE__, [module, conf, opts], name: name)
  end

  def init([module, conf, opts]) do
    children(module, conf, opts)
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp children(module, conf, opts) do

    Config.store(module, conf)

    role = Keyword.get(opts, :role, :both)

    enabled_roles = case role do
      :both       -> [:publisher, :subscriber]
      :publisher  -> [:publisher]
      :subscriber -> [:subscriber]
    end

    servers = Config.get(module, :connection, :servers)
    if length(servers) == 0 do
      raise "<Roulette> you should prepare at least one host, check your :servers configuration."
    end

    ClusterChooser.init(module, servers)

    conf = [
      pool_size:        Config.get(module, :connection, :pool_size),
      ping_interval:    Config.get(module, :connection, :ping_interval),
      max_ping_failure: Config.get(module, :connection, :max_ping_failure),
      show_debug_log:   Config.get(module, :connection, :show_debug_log)
    ]

    cluster_supervisors =
      enabled_roles
      |> Enum.flat_map(fn role ->
        servers
        |> Enum.map(fn server ->
          cluster_supervisor(module, role, server, conf)
        end)
      end)

    if role != :publisher do
      cluster_supervisors ++ [
        {Registry, keys: :unique, name: Roulette.Registry.name(module)},
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
       module:           module,
       ping_interval:    ping_interval,
       max_ping_failure: max_ping_failure,
       show_debug_log:   show_debug_log,
       pool_name:        pool,
       pool_size:        pool_size]}

  end

end
