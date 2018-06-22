defmodule Roulette.SubscriptionSupervisor do

  use DynamicSupervisor

  def start_link(module) do
    name = supervisor_name(module)
    DynamicSupervisor.start_link(__MODULE__, nil, name: name)
  end

  @impl DynamicSupervisor
  def init(_args) do
    #[{Roulette.Subscription, []}]
    #|> Supervisor.init(strategy: :simple_one_for_one)
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(module, pool, consumer, topic) do

    sup = supervisor_name(module)

    opts = %{
      module:    module,
      pool:      pool,
      consumer:  consumer,
      topic:     topic,
    }

    child = {Roulette.Subscription, [opts]}

    DynamicSupervisor.start_child(sup, child)

  end

  def terminate_child(sup_name, pid) do
    Supervisor.terminate_child(sup_name, pid)
  end

  defp supervisor_name(module) do
    Module.concat(module, SubscriptionSupervisor)
  end

end
