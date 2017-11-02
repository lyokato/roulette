defmodule Roulette.ClusterChooser do

  def choose(topic) do

    [ring, pools_list] = FastGlobal.get(:roulette_clusters)

    idx = HashRing.find_node(ring, topic)

    Enum.at(pools_list, String.to_integer(idx))

  end

  def init(pools_list) do

    len = length(pools_list)

    ring = idx_list(len) |> Enum.reduce(HashRing.new(), fn idx, ring ->
      {:ok, ring2} = HashRing.add_node(ring, "#{idx}")
      ring2
    end)

    FastGlobal.put(:roulette_clusters, [ring, pools_list])

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
