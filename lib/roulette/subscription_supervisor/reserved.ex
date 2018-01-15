defmodule Roulette.SubscriptionSupervisor.Reserved do

  alias Roulette.SubscriptionSupervisor

  def child_spec(_opts) do
    SubscriptionSupervisor.child_spec(__MODULE__)
  end

  def start_link(_opts) do
    SubscriptionSupervisor.start_link(__MODULE__)
  end

  def start_child(pool, consumer, topic) do
    SubscriptionSupervisor.start_child(__MODULE__,
                                       pool,
                                       consumer,
                                       topic,
                                       :reserved)
  end

  def terminate_child(pid) do
    SubscriptionSupervisor.terminate_child(__MODULE__, pid)
  end

end
