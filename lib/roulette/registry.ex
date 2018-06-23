defmodule Roulette.Registry do

  @spec register(module, pid, String.t) ::
    {:ok, pid()} | {:error, {:already_registered, pid()}}
  def register(module, consumer, topic) do
    name = name(module)
    Registry.register(name, {consumer, topic}, nil)
  end

  @spec lookup(module, pid, String.t) ::
    {:ok, pid} | {:error, :not_found}
  def lookup(module, consumer, topic) do
    name = name(module)
    case Registry.lookup(name, {consumer, topic}) do
      [{pid, _}] -> {:ok, pid}
      _          -> {:error, :not_found}
    end
  end

  @spec name(atom) :: atom
  def name(module) do
    Module.concat(module, Registry)
  end

end
