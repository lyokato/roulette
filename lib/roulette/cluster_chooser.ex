defmodule Roulette.ClusterChooser do

  def choose(type, topic) do

    [ring, hosts] = FastGlobal.get(type)

    idx = HashRing.find_node(ring, topic)

    Enum.at(hosts, String.to_integer(idx))

  end

  def init(type, hosts) do

    len = length(hosts)

    ring = idx_list(len) |> Enum.reduce(HashRing.new(), fn idx, ring ->
      {:ok, ring2} = HashRing.add_node(ring, "#{idx}")
      ring2
    end)

    FastGlobal.put(type, [ring, hosts])

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
