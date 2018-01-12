defmodule Roulette.ClusterSupervisor do

  use Supervisor

  def child_spec(opts) do
    %{
      id: Keyword.fetch!(opts, :name),
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5_000,
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
    interval = Keyword.fetch!(opts, :retry_interval)
    size     = Keyword.fetch!(opts, :pool_size)

    children(name, host, port, interval, size)
    |> Supervisor.init(strategy: :one_for_one)

  end

  defp children(name, host, port, interval, size) do
    [:poolboy.child_spec(name,
      pool_opts(name, size),
      [host:           host,
       port:           port,
       retry_interval: interval])]
  end

  defp pool_opts(name, size) do
    [{:name, {:local, name}},
     {:worker_module, Roulette.ConnectionKeeper},
     {:size, size},
     {:max_overflow, size}]
  end

end
