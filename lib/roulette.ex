defmodule Roulette do

  defmacro __using__(opts \\ []) do
    quote location: :keep, bind_quoted: [opts: opts] do

      @config Roulette.Config.load(__MODULE__, opts)

      @spec pub(String.t, any) :: :ok | :error
      def pub(topic, data) do
        Roulette.Publisher.pub(__MODULE__, topic, data)
      end

      @spec pub!(String.t, any) :: :ok
      def pub!(topic, data) do
        case pub(topic, data) do
          :ok    -> :ok
          :error -> raise Roulette.Error, "failed to pub: #{topic}"
        end
      end

      @spec sub(String.t) :: Supervisor.on_start
      def sub(topic) do
        Roulette.Subscriber.sub(__MODULE__, topic)
      end

      @spec sub!(String.t) :: pid
      def sub!(topic) do
        case sub(topic) do
          {:ok, pid} -> pid
          other      -> raise Roulette.Error, "failed to sub: #{inspect other}"
        end
      end

      @spec unsub(String.t | pid) :: :ok | {:error, :not_found}
      def unsub(topic_or_pid) do
        Roulette.Subscriber.unsub(__MODULE__, topic_or_pid)
      end

      @spec unsub!(String.t | pid) :: :ok
      def unsub!(topic_or_pid) do
        case unsub(topic_or_pid) do
          :ok   -> :ok
          other -> raise Roulette.Error, "failed to unsub: #{inspect other}"
        end
      end

      @spec child_spec(Keyword.t) :: Supervisor.child_spec
      def child_spec(opts \\ []) do
        Roulette.Supervisor.child_spec(__MODULE__, @config, opts)
      end

    end
  end

end
