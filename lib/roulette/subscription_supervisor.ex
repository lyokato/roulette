defmodule Roulette.SubscriptionSupervisor do

  use DynamicSupervisor

  @spec start_link([module]) :: Supervisor.on_start
  def start_link([module]) do
    name = supervisor_name(module)
    DynamicSupervisor.start_link(__MODULE__, nil, name: name)
  end

  @impl DynamicSupervisor
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_child(module, pid, String.t)
    :: DynamicSupervisor.on_start_child
  def start_child(module, consumer, topic) do

    opts = [
      module:   module,
      consumer: consumer,
      topic:    topic,
    ]

    child = {Roulette.Subscription, opts}

    module
    |> supervisor_name()
    |> DynamicSupervisor.start_child(child)

  end

  @spec terminate_child(module, pid) :: :ok | {:error, :not_found}
  def terminate_child(module, pid) do
    module
    |> supervisor_name()
    |> DynamicSupervisor.terminate_child(pid)
  end

  defp supervisor_name(module) do
    Module.concat(module, SubscriptionSupervisor)
  end

end
