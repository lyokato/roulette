defmodule Roulette.Subscriber do

  require Logger

  alias Roulette.AtomGenerator
  alias Roulette.ClusterChooser
  alias Roulette.SubscriptionSupervisor

  @spec sub(String.t) :: Supervisor.on_start_child
  def sub(topic) do
    Logger.debug "SUB: #{topic}"
    consumer = self()
    case :gproc.where({:n, :l, {consumer, topic}}) do
      :undefined ->
        choose_pool(topic)
        |> SubscriptionSupervisor.start_child(consumer, topic)
      pid ->
        {:error, {:already_started, pid}}
    end
  end

  defp choose_pool(topic) do
    host = ClusterChooser.choose(topic)
    AtomGenerator.cluster_pool(:subscriber, host)
  end

  @spec unsub(pid) :: :ok
  def unsub(subscription) when is_pid(subscription) do
    SubscriptionSupervisor.terminate_child(subscription)
    :ok
  end

  @spec unsub(String.t) :: :ok
  def unsub(topic) when is_binary(topic) do
    Logger.debug "UNSUB: #{topic}"
    case :gproc.where({:n, :l, {self(), topic}}) do
      :undefined -> :ok
      pid        -> unsub(pid)
    end
  end

end
