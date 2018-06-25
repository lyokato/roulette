defmodule Roulette do

  @moduledoc ~S"""

  Scalable PubSub client library which uses HashRing-ed gnatsd-cluster

  ## Prepare your own PubSub module

  ```elixir
  defmodule MyApp.PubSub do
    use Roulette, otp_app: :my_app
  end
  ```

  ## Configuration

  Setup configuration like following

  ```elixir
  config :my_app, MyApp.PubSub,
      servers: [
        [host: "gnatsd1.example.org", port: 4222],
        [host: "gnatsd2.example.org", port: 4222],
        [host: "gnatsd3.example.org", port: 4222]
      ]
      # ...
  ```

  ## Application

  Append your PubSub module onto your application's supervisor

  ```elixir
  defmodule MyApp.Application do
    use Application

    def start(_type, _args) do
      children = [
        {MyApp.Pubsub, []}
        # ... other children
      ]
      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor..start_link(children, opts)
    end

  end
  ```

  ## Simple Usage

  ```elixir
  defmodule MyApp.Session do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(opts) do
      username = Keyword.fetch!(opts, :username)
      MyApp.PubSub.sub!(username)
      {:ok, %{username: username}}
    end

    def handle_info({:pubsub_message, topic, msg, pid}, state) do
      # handle msg
      {:noreply, state}
    end

    def terminate(reason, state) do
      :ok
    end

  end
  ```

  Anywhere else you want to publish message in your app.

  ```elixir
  MyApp.PubSub.pub!("foobar", data)
  ```

  ## Premised gnatsd Network Architecture

  gnatsd supports cluster-mode. This works with full-mesh and one-hop messaging system to sync events.

  [gnatsd's full-mesh architecture](https://github.com/nats-io/gnatsd#full-mesh-required)

  ![roulette_01](https://user-images.githubusercontent.com/30877/41829326-0c040e5a-7875-11e8-8680-d89bf8ccbd39.png)

  Roulette assumes that you put a load-balancer like AWS-NBL in front of each gnatsd-clusters.

  Roulette doesn't have a responsiblity for health-check and load-balancing between gnatsd-servers
  exists in a single gnatsd-cluster.
  Roulette assumes that It's a load-balancers' responsibility.

  ![roulette_02](https://user-images.githubusercontent.com/30877/41829331-0e27822a-7875-11e8-8407-fce8268e06ac.png)

  Roulette connects to each gnatsd-server through load-balancers,
  and doesn't mind which endpoint it connects to.

  However if your application servers send `PUBLISH` so much,
  it'll cause troubles eventuallly.

  Roulette resolves this problem with `Consistent Hashing`.

  Setup multiple gnatsd-cluster beforehand, and when your app sends
  `PUBLISH` or `SUBSCRIBE` message,
  "Which cluster your app sends message to" is decided by the `topic`.


  ![roulette_03](https://user-images.githubusercontent.com/30877/41829333-0f67267c-7875-11e8-994a-745fec2ebdd6.png)

  ## Detailed Usage

  ### Publish

  ok/error style.

  ```elixir
  topic = "foobar"

  case MyApp.PubSub.pub(topic, data) do

    :ok -> :ok

    :error -> :error

  end
  ```

  If you don't mind error handling(not recommended on production),
  you can use `pub!/2` instead

  ```elixir
  topic = "foobar"

  MyApp.PubSub.pub!(topic, data)
  ```

  ### Subscribe

  ok/error style.

  `sub/1` returns Supervisor.on_start()

  ```elixir
  topic = "foobar"

  case MyApp.PubSub.sub("foobar") do

    {:ok, _pid} -> :ok

    other ->
      Logger.warn "failed to sub: #{inspect other}"
      :error

  end
  ```

  If you don't mind error handling(not recommended on production),
  you can use `sub!/1` instead

  ```elixir
  MyApp.PubSub.sub!(topic)
  ```

  ### Unsubscribe

  ok/error style.

  `sub/1` returns Supervisor.on_start()

  ```elixir
  topic = "foobar"

  case MyApp.PubSub.unsub("foobar") do

    :ok -> :ok

    {:error, :not_found} -> :ok

  end
  ```

  If you don't mind error handling(not recommended on production),
  you can use `unsub!/1` instead

  ```elixir
  MyApp.PubSub.unsub!(topic)
  ```

  In following example, you don't need to call `unsub/1` on `terminate/2`.
  Because unsub is automatically handled, the process which calls `sub` terminates.

  ```elixir
  defmodule MyApp.Session do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(opts) do
      username = Keyword.fetch!(opts, :username)
      MyApp.PubSub.sub!(username)
      {:ok, %{username: username}}
    end

    def handle_info({:pubsub_message, topic, msg, pid}, state) do
      # handle msg
      {:noreply, state}
    end

    def terminate(reason, state) do
      # You don't need this line
      # MyApp.PubSub.unsub(state.username)
      :ok
    end

  end
  ```

  """

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

      @spec child_spec(any) :: Supervisor.child_spec
      def child_spec(_opts) do
        Roulette.Supervisor.child_spec(__MODULE__, @config)
      end

    end
  end

end
