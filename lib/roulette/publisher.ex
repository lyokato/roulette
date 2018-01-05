defmodule Roulette.Publisher do

  require Logger

  alias Roulette.ClusterChooser
  alias Roulette.Config
  alias Roulette.ConnectionKeeper

  @spec pub(String.t, any) :: :ok | :error
  def pub(topic, data) do
    max_retry = Config.get(:publisher, :max_retry)
    ClusterChooser.choose(topic)
    |> pub_on_cluster(topic, data, 0, max_retry)
  end

  defp pub_on_cluster(pool, topic, data, retry, max_retry) do
    :poolboy.transaction(pool, fn conn_keeper ->

      case ConnectionKeeper.connection(conn_keeper) do

        {:ok, gnat} ->
          case Gnat.pub(gnat, topic, data) do

            :ok -> :ok

            other when retry < max_retry ->
              Logger.warn "<Roulette.Publisher> failed to pub: #{inspect other}, retry."
              pub_on_cluster(pool, topic, data, retry + 1, max_retry)

            other ->
              Logger.error "<Roulette.Publisher> failed to pub: #{inspect other}"
              :error

          end

        {:error, :not_found} when retry < max_retry ->
          Logger.warn "<Roulette.Publisher> connection lost, try to find other."
          pub_on_cluster(pool, topic, data, retry + 1, max_retry)

        {:error, :not_found} ->
          Logger.error "<Roulette.Publisher> connection lost"
          :error

      end

    end)
  end

end
