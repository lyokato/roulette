defmodule Roulette.ClusterSupervisor do

  use Supervisor

  def child_spec(opts) do
    %{
      id: Keyword.fetch!(opts, :name),
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do

    name     = Keyword.fetch!(opts, :pool_name)
    host     = Keyword.fetch!(opts, :host)
    port     = Keyword.fetch!(opts, :port)
    size     = Keyword.fetch!(opts, :pool_size)

    ping_interval  = Keyword.fetch!(opts, :ping_interval)
    show_debug_log = Keyword.fetch!(opts, :show_debug_log)

    max_ping_failure = Keyword.fetch!(opts, :max_ping_failure)

    children(name,
             host,
             port,
             show_debug_log,
             ping_interval,
             max_ping_failure,
             size)
    |> Supervisor.init(strategy: :one_for_one)

  end

  defp children(name, host, port, show_debug_log, ping_interval, max_ping_failure, size) do
    [:poolboy.child_spec(name,
      pool_opts(name, size),
      [host:             host,
       port:             port,
       show_debug_log:   show_debug_log,
       max_ping_failure: max_ping_failure,
       ping_interval:    ping_interval])]
  end

  defp pool_opts(name, size) do
    [{:name, {:local, name}},
     {:worker_module, Roulette.Connection},
     {:size, size},
     {:strategy, :fifo},
     {:max_overflow, 0}]
  end

end
