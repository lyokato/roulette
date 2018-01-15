defmodule Roulette.Subscriber do

  @spec sub(String.t) :: Supervisor.on_start_child
  def sub(topic) do

    if FastGlobal.get(:roulette_use_reserved_ring) do

      case Roulette.Subscriber.SingleRing.sub(:default, topic) do

        {:ok, default_pid} ->
          case Roulette.Subscriber.SingleRing.sub(:reserved, topic) do

            {:ok, _reserved_pid} ->
              # TODO bad response format, we should include 'reserved_pid'
              {:ok, default_pid}

            error ->
              Roulette.Subscriber.SingleRing.unsub(:default, default_pid)
              error

          end

        error -> error

      end

    else

      Roulette.Subscriber.SingleRing.sub(:default, topic)

    end

  end

  @spec unsub(topic :: String.t) :: :ok
  def unsub(topic) do

    Roulette.Subscriber.SingleRing.unsub(:default, topic)

    if FastGlobal.get(:roulette_use_reserved_ring) do
      Roulette.Subscriber.SingleRing.unsub(:reserved, topic)
    end

    :ok
  end

end
