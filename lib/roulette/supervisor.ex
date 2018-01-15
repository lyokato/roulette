defmodule Roulette.Supervisor do

  require Logger

  use Supervisor

  alias Roulette.AtomGenerator
  alias Roulette.ClusterChooser
  alias Roulette.ClusterSupervisor
  alias Roulette.Config
  alias Roulette.SubscriptionSupervisor

  @type role :: :both | :subscriber | :publisher

  @default_port 4222

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

    ClusterChooser.init(ring)

    enabled_roles = case role do
      :both       -> [:publisher, :subscriber]
      :publisher  -> [:publisher]
      :subscriber -> [:subscriber]
    end

    pool_size      = Config.get(:connection, :pool_size)
    retry_interval = Config.get(:connection, :retry_interval)

    cluster_supervisors = enabled_roles |> Enum.flat_map(fn role ->

      ring |> Enum.map(fn target ->

       cluster_supervisor(role,
                          target,
                          pool_size,
                          retry_interval)

      end)

    end)

    if role != :publisher do
      [{SubscriptionSupervisor, []}] ++ cluster_supervisors
    else
      cluster_supervisors
    end

  end

  defp cluster_supervisor(role, target, pool_size, retry_interval) do

    {host, port} = get_host_and_port(target)
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

  defp get_host_and_port(target) when is_binary(target) do
    {target, @default_port}
  end
  defp get_host_and_port(target) do
    host = Keyword.fetch!(target, :host)
    port = Keyword.get(target, :port, @default_port)
    {host, port}
  end

end
