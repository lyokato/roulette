defmodule Roulette do

  @moduledoc """
  Roulette is a HashRing-ed gnatsd-cluster client library

  See https://github.com/lyokato/roulette
  """

  defmacro __using__(opts \\ []) do
    quote location: :keep, bind_quoted: [opts: opts] do

      @config Roulette.Config.load(__MODULE__, opts)

      @spec pub(String.t, any) :: :ok | :error
      def pub(topic, data) do
        Roulette.Publisher.pub(__MODULE__, topic, data)
      end

      @spec sub(String.t) :: :ok | :error
      def sub(topic, data) do
        Roulette.Subscriber.sub(__MODULE__, topic)
      end

      @spec unsub(String.t) :: :ok
      def unsub(topic, data) do
        Roulette.Subscriber.unsub(__MODULE__, pid_or_topic)
      end

      def child_spec(opts \\ []) do
        Roulette.Supervisor.child_spec(__MODULE__, opts)
      end

    end
  end

end
