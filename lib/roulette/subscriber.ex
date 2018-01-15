defmodule Roulette.Subscriber do

  require Logger

  alias Roulette.AtomGenerator
  alias Roulette.ClusterChooser
  alias Roulette.Config
  alias Roulette.SubscriptionSupervisor

  @spec sub(String.t) :: Supervisor.on_start_child
  def sub(topic) do
    consumer = self()
    case :gproc.where({:n, :l, {consumer, topic}}) do
      :undefined ->
        choose_pool(topic)
        |> SubscriptionSupervisor.Default.start_child(consumer, topic)
      pid ->
        {:error, {:already_started, pid}}
    end
  end

  defp choose_pool(topic) do
    target = ClusterChooser.Default.choose(topic)
    {host, port} = Config.get_host_and_port(target)
    AtomGenerator.cluster_pool(:subscriber, host, port)
  end

  @spec unsub(pid) :: :ok
  def unsub(subscription) when is_pid(subscription) do
    SubscriptionSupervisor.Default.terminate_child(subscription)
    :ok
  end

  @spec unsub(String.t) :: :ok
  def unsub(topic) when is_binary(topic) do
    case :gproc.where({:n, :l, {self(), topic}}) do
      :undefined -> :ok
      pid        -> unsub(pid)
    end
  end

end
