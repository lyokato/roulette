defmodule Roulette.ClusterChooser do

  def choose(topic) do

    [ring, hosts] = FastGlobal.get(:roulette_clusters)

    idx = HashRing.find_node(ring, topic)

    Enum.at(hosts, String.to_integer(idx))

  end

  def init(hosts) do

    len = length(hosts)

    ring = idx_list(len) |> Enum.reduce(HashRing.new(), fn idx, ring ->
      {:ok, ring2} = HashRing.add_node(ring, "#{idx}")
      ring2
    end)

    FastGlobal.put(:roulette_clusters, [ring, hosts])

  end

  defp idx_list(0) do
    raise "must not come here"
  end
  defp idx_list(1) do
    [0]
  end
  defp idx_list(len) do
    (0..(len - 1)) |> Enum.to_list()
  end

end
