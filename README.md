# Roulette

Scalable PubSub client library which uses HashRing-ed gnatsd-cluster

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `roulette` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:roulette, "~> 1.0.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/roulette](https://hexdocs.pm/roulette).

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
Roulette assumes that It's load-balancers' responsibility.

![roulette_02](https://user-images.githubusercontent.com/30877/41829331-0e27822a-7875-11e8-8407-fce8268e06ac.png)

Roulette connects to each backend gnatsd-server through load-balancers,
and doesn't mind which endpoint to connect to.

However if your application servers send `PUBLISH` so much,
it'll cause troubles eventuallly.

![roulette_03](https://user-images.githubusercontent.com/30877/41829333-0f67267c-7875-11e8-994a-745fec2ebdd6.png)

Roulette resolves this problem with `Consistent Hashing`.

Setup multiple gnatsd-cluster beforehand, and when your app sends
`PUBLISH` or `SUBSCRIBE` message,
"Which cluster your app sends message to" is decided by the `topic`.

## Full Configuration Description

Here is a minimum configuration example,
You must setup `servers` list.
Put your load-balancers' hostname into it.

```elixir
config :my_app, MyApp.PubSub,
  servers: [
    "gnatsd-cluster1.example.org",
    "gnatsd-cluster2.example.org"
  ]

```

Or else, you can use keyword list for each host.

```elixir
config :my_app, MyApp.PubSub,
  servers: [
    [host: "gnatsd-cluster1.example.org", port: 4222],
    [host: "gnatsd-cluster2.example.org", port: 4222]
  ]
```

If there is no `port` setting, 4222 is set by defaut.

|key|default|description|
|:--|:--|:--|
|role|:both|You can choose **:subscriber**, **:publisher**, or **:both**|
|servers|required|servers list used as hash-ring|
|pool_size|5|number of connections for each gnatsd-cluster|
|ping_interval|5_000|sends PING message to gnatsd with this interval (milliseconds)|
|max_ping_failure|2|if PONG doesn't return while this number of PING sends, Roulette disconnects the connection.|
|max_retry|10|When it fails to send PUBLISH or SUBSCRIBE messages, it automatically retry|
|max_backoff|5_000|max duration(milliseconds) used to calculate backoff period|
|base_backoff|10|base number used to calculate backoff period|
|show_debug_log|false|if this is true, Roulette dumps many debug logs.|
|subscription_restart|**:temporary**|You can choose **:temporary** or **:permanent**|

### role

- :both (default) - setup both `Publisher` and `Subscriber` connections
- :subscriber - setup `Subscriber` connections only
- :publisher - setup `Publisher` connections only

### subscription_restart

#### :temporary

subscription-process sends EXIT message to consumer process when gnatsd-connection is disconnected.

#### :permanent

subscription-process try to keep subscription.
when gnatsd-connection is disconnected, retry to sends SUBSCRIBE message through other connections.

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

## LICENSE

MIT-LICENSE

## Author

Lyo Kaot <lyo.kato __at__ gmail.com>

