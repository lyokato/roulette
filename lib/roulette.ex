defmodule Roulette do

  @moduledoc """
  Roulette is a HashRing-ed gnatsd-cluster client library

  See https://github.com/lyokato/roulette
  """

  defmacro __using__(opts \\ []) do
    quote location: :keep, bind_quoted: [opts: opts] do

      require Logger

      @config Roulette.Config.load(__MODULE__, opts)

      @spec pub(String.t, any) :: :ok | :error
      def pub(topic, data) do
        Roulette.Publisher.pub(__MODULE__, topic, data)
      end

      @spec sub(String.t) :: :ok | :error
      def sub(topic) do
        case Roulette.Subscriber.sub(__MODULE__, topic) do
          {:ok, _pid} -> :ok
          other ->
            Logger.warn "<Roulette> failed to sub: #{inspect other}"
            :error
        end
      end

      @spec unsub(String.t) :: :ok
      def unsub(topic) do
        Roulette.Subscriber.unsub(__MODULE__, topic)
        :ok
      end

      def child_spec(opts \\ []) do
        Roulette.Supervisor.child_spec([__MODULE__, @config, opts])
      end

    end
  end

end
