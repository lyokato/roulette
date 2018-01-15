defmodule Roulette.ClusterChooser.Default do

  @name :roulette_default_clusters

  def choose(topic) do
    Roulette.ClusterChooser.choose(@name, topic)
  end

  def init(hosts) do
    Roulette.ClusterChooser.init(@name, hosts)
  end

end
