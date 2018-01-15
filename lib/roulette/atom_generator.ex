defmodule Roulette.AtomGenerator do

  @type role :: :subscriber | :publisher

  @spec cluster_pool(role :: role,
                     host :: String.t,
                     port :: pos_integer) :: atom

  def cluster_pool(role, host, port) do
    Module.concat([Roulette.ClusterConnectionPool,
                   role,
                   "#{host}_#{port}"])
  end

  @spec cluster_supervisor(role :: role,
                           host :: String.t,
                           port :: pos_integer) :: atom

  def cluster_supervisor(role, host, port) do
    Module.concat([Roulette.ClusterSupervisor,
                   role,
                   "#{host}_#{port}"])
  end

end
