defmodule Roulette.Subscriber.SingleRing do

  alias Roulette.AtomGenerator
  alias Roulette.ClusterChooser
  alias Roulette.Config
  alias Roulette.SubscriptionSupervisor

  @spec sub(ring_type :: :default | :reserved,
            topic     :: String.t)
    :: Supervisor.on_start_child

  def sub(ring_type, topic) do
    consumer = self()
    case :gproc.where({:n, :l, {consumer, topic, ring_type}}) do
      :undefined ->
        pool = choose_pool(ring_type, topic)
        supervisor = subscription_supervisor(ring_type)
        supervisor.start_child(pool, consumer, topic)
      pid ->
        {:error, {:already_started, pid}}
    end
  end

  defp choose_pool(ring_type, topic) do
    chooser = cluster_chooser(ring_type)
    target = chooser.choose(topic)
    {host, port} = Config.get_host_and_port(target)
    AtomGenerator.cluster_pool(:subscriber, host, port)
  end

  @spec unsub(ring_type :: :default | :reserved,
              topic     :: pid)
    :: :ok

  def unsub(ring_type, subscription) when is_pid(subscription) do
    supervisor = subscription_supervisor(ring_type)
    supervisor.terminate_child(subscription)
    :ok
  end

  @spec unsub(ring_type :: :default | :reserved,
              topic     :: String.t)
    :: :ok

  def unsub(ring_type, topic) when is_binary(topic) do
    case :gproc.where({:n, :l, {self(), topic, ring_type}}) do
      :undefined -> :ok
      pid        -> unsub(ring_type, pid)
    end
  end

  defp subscription_supervisor(:default),  do: SubscriptionSupervisor.Default
  defp subscription_supervisor(:reserved), do: SubscriptionSupervisor.Reserved

  defp cluster_chooser(:default),  do: ClusterChooser.Default
  defp cluster_chooser(:reserved), do: ClusterChooser.Reserved

end
