defmodule Roulette.Registry do

  def start_link([module]) do
    name = name(module)
    Registry.start_link(:unique, name)
  end

  def register(module, consumer, topic) do
    name = name(module)
    Registry.register(name, {consumer, topic}, [])
  end

  def lookup(module, consumer, topic) do
    name = name(module)
    case Registry.lookup(name, {consumer, topic}) do
      [{pid, []}] -> {:ok, pid}
      _           -> {:error, :not_found}
    end
  end

  defp name(module) do
    Module.concat(module, Registry)
  end

end
