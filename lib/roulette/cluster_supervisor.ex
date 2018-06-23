defmodule Roulette.ClusterSupervisor do

  use Supervisor

  @type role :: :subscriber | :publisher

  @spec child_spec(Keyword.t) :: Supervisor.child_spec
  def child_spec(opts) do
    %{
      id: Keyword.fetch!(opts, :name),
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @spec name(module, role, String.t, pos_integer) :: atom
  def name(module, role, host, port) do
    Module.concat([
      module,
      ClusterSupervisor,
      role,
      "#{host}_#{port}"
    ])
  end

  @spec start_link(Keyword.t) :: Supervisor.on_start
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(opts) do
    opts
    |> children()
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp children(opts) do

    module           = Keyword.fetch!(opts, :module)
    name             = Keyword.fetch!(opts, :pool_name)
    host             = Keyword.fetch!(opts, :host)
    port             = Keyword.fetch!(opts, :port)
    size             = Keyword.fetch!(opts, :pool_size)
    ping_interval    = Keyword.fetch!(opts, :ping_interval)
    show_debug_log   = Keyword.fetch!(opts, :show_debug_log)
    max_ping_failure = Keyword.fetch!(opts, :max_ping_failure)

    pool_opts = pool_opts(name, size)

    conn_opts = [
      module:           module,
      host:             host,
      port:             port,
      show_debug_log:   show_debug_log,
      max_ping_failure: max_ping_failure,
      ping_interval:    ping_interval
    ]

    [:poolboy.child_spec(name, pool_opts, conn_opts)]
  end

  defp pool_opts(name, size) do
    [{:name, {:local, name}},
     {:worker_module, Roulette.Connection},
     {:size, size},
     {:strategy, :fifo},
     {:max_overflow, 0}]
  end

end
