defmodule Roulette.Subscriber do

  alias Roulette.Registry
  alias Roulette.SubscriptionSupervisor

  @spec sub(module, String.t) ::
    DynamicSupervisor.on_start_child
  def sub(module, topic) do
    consumer = self()
    case Registry.lookup(module, consumer, topic) do
      {:error, :not_found} -> do_sub(module, consumer, topic)
      {:ok, pid}           -> {:error, {:already_started, pid}}
    end
  end

  defp do_sub(module, consumer, topic) do
    SubscriptionSupervisor.start_child(
      module,
      consumer,
      topic
    )
  end

  @spec unsub(module, pid) :: :ok | {:error, :not_found}
  def unsub(module, subscription) when is_pid(subscription) do
    Process.unlink(subscription)
    SubscriptionSupervisor.terminate_child(module, subscription)
  end

  @spec unsub(module, String.t) :: :ok | {:error, :not_found}
  def unsub(module, topic) when is_binary(topic) do
    consumer = self()
    case Registry.lookup(module, consumer, topic) do
      {:error, :not_found} -> :ok
      {:ok, pid}           -> unsub(module, pid)
    end
  end

end
