defmodule Roulette.Subscriber do

  alias Roulette.ClusterChooser
  alias Roulette.SubscriptionSupervisor

  @spec sub(String.t) :: Supervisor.on_start_child
  def sub(topic) do
    consumer = self()
    case :gproc.where({:n, :l, {consumer, topic}}) do
      :undefined ->
        ClusterChooser.choose(topic)
        |> SubscriptionSupervisor.start_child(consumer, topic)
      pid ->
        {:error, {:already_started, pid}}
    end
  end

  @spec unsub(pid) :: :ok
  def unsub(subscription) do
    SubscriptionSupervisor.terminate_child(subscription)
    :ok
  end

  @spec unsub(String.t) :: :ok
  def unsub(topic) do
    case :gproc.where({:n, :l, {self(), topic}}) do
      :undefined -> :ok
      pid        -> unsub(pid)
    end
  end

end
