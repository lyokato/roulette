defmodule Roulette.SubscriptionSupervisor do

  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    [worker(Roulette.Subscription, [])]
    |> supervise(strategy: :simple_one_for_one)
  end

  def start_child(pool, consumer, topic) do
    opts = %{
      pool:     pool,
      consumer: consumer,
      topic:    topic
    }
    Supervisor.start_child(__MODULE__, opts)
  end

  def terminate_child(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end

end
