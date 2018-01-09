defmodule Roulette.AtomGenerator do

  @type role :: :subscriber | :publisher

  @spec cluster_pool(role :: role,
                     host :: String.t) :: atom

  def cluster_pool(role, host) do
    Module.concat([Roulette.ClusterConnectionPool,
                   role,
                   host])
  end

  @spec cluster_supervisor(role :: role,
                           host :: String.t) :: atom

  def cluster_supervisor(role, host) do
    Module.concat([Roulette.ClusterSupervisor,
                   role,
                   host])
  end

end
