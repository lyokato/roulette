defmodule Roulette.Subscriber do

  @moduledoc ~S"""
  Subscriber module. this provides just two functions, `sub/1` and `unsub/1`.

  This is designed to be used with for each micro-process,
  like a implementation which uses GenServer.

  ## Usage

      defmodule MySession do

        use GenServer
        require Logger

        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(opts) do
          username = Keyword.fetch!(opts, :username)

          case Roulette.Subscriber.sub(username) do

            {:ok, _pid} ->
              {:ok, %{username: username}}

            other ->
              Logger.warn "failed to sub: #{inspect other}"
              {:stop, :setup_failure}
          end

        end

        def handle_info({:pubsub_message, topic, data, pid}, state) do
          # handle_received_message(data)
          {:noreply, state}
        end

        # Implements some other `handle_info`, `handle_cast`, `handle_call` functions.
        # ...

        def terminate(_reason, state) do
          Roulette.Subscriber.unsub(state.username)
          :ok
        end

      end
  """

  @doc ~S"""
  Start subscription with a `topic`.

  ## Usage

      username = "foobar"
      case Roulette.Subscriber.sub(foobar) do
        {:ok, _subscription_pid} -> :ok
        other                    -> {:error, :fialure}
      end


  Internallly, `roulette` chooses a proper gnatsd-cluster for the `topic`.
  For this choice, `consistent-hashing` is utilized.

  Then, a process-pool for the cluster pick a GenServer process which keeps
  connection to gnatsd-server. Within this connection, `roulette` tries to send a
  `SUBSCRIBE` message.

  If it failed, automatically retry until it succeeds or reached to the
  limit number that you set on your configuration as `max_retry`.

  After it succeeds, you can wait a data that someone `Publish` with this `topic`.

  If the caller process is GenServer, you should write `handle_info/2`
  for this purpose like following.

  ## Usage

        def handle_info({:pubsub_message, topic, data, pid}, state) do
          # handle_received_message(data)
          {:noreply, state}
        end

  """

  @spec sub(topic :: String.t) :: Supervisor.on_start_child

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

  @doc ~S"""
  Stop subscription bound to a topic.

  # Usage

      username = "foobar"
      Roulette.Subscriber.unsub(foobar)


  If proper-subscription for a topic doesn't exit, it just ignores.

  In above example, we wrote like

      def terminate(_reason, state) do
        Roulette.Subscriber.unsub(state.username)
        :ok
      end


  But the truth, if you want to `unsub` when the process `terminate`,
  You don't need to call `unsub`. Because the subscription process is
  monitoring your process, and when it'll be down, subscription process
  starts to die togather.
  """

  @spec unsub(topic :: String.t) :: :ok

  def unsub(topic) do

    Roulette.Subscriber.SingleRing.unsub(:default, topic)

    if FastGlobal.get(:roulette_use_reserved_ring) do
      Roulette.Subscriber.SingleRing.unsub(:reserved, topic)
    end

    :ok
  end

end
