defmodule Roulette.Subscriber do

  alias Roulette.ClusterPool
  alias Roulette.Registry
  alias Roulette.SubscriptionSupervisor

  @spec sub(module :: module,
            topic  :: String.t) :: Supervisor.on_start_child

  def sub(module, topic) do

    consumer = self()

    case Registry.lookup(module, consumer, topic) do

      {:error, :not_found} ->

        pool = ClusterPool.choose(module, :subscriber, topic)

        SubscriptionSupervisor.start_child(
          module,
          pool,
          consumer,
          topic
        )

      {:ok, pid} ->

        {:error, {:already_started, pid}}

    end
  end

  @spec unsub(module :: module,
              topic  :: pid) :: :ok

  def unsub(module, subscription) when is_pid(subscription) do
    SubscriptionSupervisor.terminate_child(module, subscription)
    :ok
  end

  @spec unsub(modle :: module,
              topic :: String.t) :: :ok

  def unsub(module, topic) when is_binary(topic) do

    consumer = self()

    case Registry.lookup(module, consumer, topic) do

      {:error, :not_found} -> :ok

      {:ok, pid} -> unsub(module, pid)

    end
  end

end
