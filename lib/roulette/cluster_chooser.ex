defmodule Roulette.ClusterChooser do

  alias Roulette.Util.IndexList
  alias ExHashRing.HashRing

  def choose(module, topic) do
    [ring, hosts] = FastGlobal.get(module)
    idx = HashRing.find_node(ring, topic)
    Enum.at(hosts, String.to_integer(idx))
  end

  def init(module, hosts) do

    ring =
      hosts
      |> length()
      |> IndexList.new()
      |> Enum.reduce(HashRing.new(), fn idx, ring ->
        {:ok, ring2} = HashRing.add_node(ring, "#{idx}")
        ring2
      end)

    FastGlobal.put(module, [ring, hosts])

  end

end
