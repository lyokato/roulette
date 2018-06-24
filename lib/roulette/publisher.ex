defmodule Roulette.Publisher do

  @moduledoc ~S"""
  Publisher module. this provides just a single function,
  """

  require Logger

  alias Roulette.ClusterPool
  alias Roulette.Config
  alias Roulette.Connection
  alias Roulette.NatsClient
  alias Roulette.Util.Backoff

  @checkout_timeout 5_100

  @doc ~S"""
  Publish a message-data with a `topic`

  Internallly, `roulette` chooses a proper gnatsd-cluster for the `topic`.
  For this choice, `consistent-hashing` is utilized.

  Then, a process-pool for the cluster picks a GenServer process which keeps
  connection to gnatsd-server. Within this connection, `roulette` tries to send
  `PUBLISH` messages.

  If it failed, automatically retry until it succeeds or reaches to the
  limit number that you set on your configuration as `max_retry`.
  """

  @spec pub(module, String.t, binary) :: :ok | :error
  def pub(module, topic, data) do

    pool      = ClusterPool.choose(module, :publisher, topic)
    max_retry = Config.get(module, :max_retry)
    attempts  = 0

    pub_on_cluster(
      module,
      pool,
      topic,
      data,
      attempts,
      max_retry
    )

  end

  defp pub_on_cluster(module, pool, topic, data, attempts, max_retry) do

    case do_pub_on_cluster(pool, topic, data) do

      :ok -> :ok

      :error when attempts < max_retry ->
        attempts |> calc_backoff(module) |> Process.sleep()
        pub_on_cluster(module, pool, topic, data, attempts + 1, max_retry)

      :error ->
        Logger.error "<Roulette.Publisher> failed to pub eventually"
        :error

    end
  end

  defp do_pub_on_cluster(pool, topic, data) do
    try do
      :poolboy.transaction(pool, fn conn ->

        case Connection.get(conn) do

          {:ok, nats} ->
            case do_nats_pub(nats, topic, data) do

              :ok -> :ok

              other ->
                Logger.warn "<Roulette.Publisher> failed to pub: #{inspect other}"
                :error

            end

          {:error, :timeout} ->
            Logger.warn "<Roulette.Publisher> failed to checkout connection: timeout (maybe closing)"
            :error

          {:error, :not_found} ->
            Logger.warn "<Roulette.Publisher> connection lost"
            :error

        end

      end, @checkout_timeout)
    catch
      :exit, _e ->
        Logger.warn "<Roulette.Publisher> failed to checkout connection: timeout"
        :error
    end
  end

  defp calc_backoff(attempts, module) do
    Backoff.calc(module, attempts)
  end

  defp do_nats_pub(nats, topic, data) do
    try do
      NatsClient.pub(nats, topic, data)
    catch
      # if it takes 5_000 milli seconds (5_000 is default setting for GenServer.call)
      :exit, e ->
        Logger.warn "<Roulette.Subscription> failed to pub: #{inspect e}"
        {:error, :timeout}
    end
  end

end
