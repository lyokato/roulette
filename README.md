# Roulette

HashRing-ed gnatsd-cluster client library

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

THIS DOCUMENT WILL BE TRANSLATED TO ENGLISH LATER

## Prepare Your Own PubSub module

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

## Usage

Subscribe events.

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

[image]

Roulette assumes that you put a load-balancer like AWS-NBL in front of each gnatsd-clusters.

Roulette doesn't have a responsiblity for health-check and load-balancing between gnatsd-servers
exists in a single gnatsd-cluster.
Roulette assumes that It's load-balancers' responsibility.

[image]

Roulette connects to each backend gnatsd-server through load-balancers,
and doesn't mind which endpoint to connect to.

However if your application servers send `PUBLISH` so much,
it'll cause troubles eventuallly.

[image]

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

- ping_interval: after a connection established, repeatedly send PING message with this interval (milli seconds). 5_000 is set by default.
- pool_size: how many connections for each gnatsd-cluster. 5 is set by default.

If you want to arrange them, the setting become like following.

```elixir
config :my_app, MyApp.PubSub,
  servers: [
    [host: "gnatsd-cluster1.example.org", port: 4222],
    [host: "gnatsd-cluster2.example.org", port: 4222]
  ],
  ping_interval: 1_000,
  pool_size: 10

```

You can pass `role` parameter

- :both (default) - setup both `Publisher` and `Subscriber` connections
- :subscriber - setup `Subscriber` connections only
- :publisher - setup `Publisher` connections only

## Detailed description about Publish/Subscribe behaviour

## Ring Update: Take a service downtime or 3-phase deploy with Reserved-Ring

