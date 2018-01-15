defmodule Roulette.SubscriptionSupervisor do

  use Supervisor

  def child_spec(sup_name) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [sup_name]},
      type: :supervisor
    }
  end

  def start_link(sup_name) do
    Supervisor.start_link(__MODULE__, nil, name: sup_name)
  end

  def init(_args) do
    [{Roulette.Subscription, []}]
    |> Supervisor.init(strategy: :simple_one_for_one)
  end

  def start_child(sup_name, pool, consumer, topic) do
    opts = %{
      pool:     pool,
      consumer: consumer,
      topic:    topic
    }
    Supervisor.start_child(sup_name, [opts])
  end

  def terminate_child(sup_name, pid) do
    Supervisor.terminate_child(sup_name, pid)
  end

end
