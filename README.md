# Roulette

HashRing-ed gnatsd-cluster client library

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `roulette` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:roulette, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/roulette](https://hexdocs.pm/roulette).

## Simple Usage Example

Configuration

```elixir
config :roulette, :connection,
  ring: [
    "gnatsd-cluster1.example.org",
    "gnatsd-cluster2.example.org"
  ]

```

In your application bootstrap

```elixir
children = [
  {Roulette, []},
  # ... setup other workers and supervisors
]
Supervisor.start_link(children, strategy: :one_for_one)
```

Server process in your app.

```elixir
defmodule YourSession do

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    username = Keyword.fetch!(opts, :username)
    Roulette.sub(username)
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
Roulette.pub("foobar", data)
```

## Premised gnatsd Network Architecture

gnatsd supports cluster-mode. This works with full-mesh and one-hop to sync events.

[image]

Roulette assumes that you put a load-balancer like AWS-NBL in front of for each gnatsd-clusters.

Roulette doesn't have a responsiblity for health-check and load-balancing between gnatsd-servers
exists in a single gnatsd-cluster.
It's load-balancer's responsibility.

Roulette connects to for each backend gnatsd-server through load-balancers,
and doesn't mind which endpoint to connect to.

[image]

However if your application servers send `PUBLISH` so much,
it'll cause troubles eventuallly.

[image]

Roulette resolves this problem with `Consistent Hashing`.

Setup multiple gnatsd-cluster beforehand, and when your app sends
`PUBLISH` or `SUBSCRIBE` message,
"Which cluster your app sends message to" is decided by the `topic`.

## Full Configuration Description

minimum configuration example,
You must setup `ring` list.
Put your load-balancers' hostname into it.

```elixir
config :roulette, :connection,
  ring: [
    "gnatsd-cluster1.example.org",
    "gnatsd-cluster2.example.org"
  ]

```

Or else, you can keyword list for each host.

```elixir
config :roulette, :connection,
  ring: [
    [host: "gnatsd-cluster1.example.org", port: 4222],
    [host: "gnatsd-cluster2.example.org", port: 4222]
  ]

```

If there is no `port` setting, 4222 is set by defaut.

- retry_interval: when found disconnection, or establish-connection-falure, automatically try to re-connect, after this interval (milli seconds). 1_000 is set by default.
- ping_interval: after a connection established, repeatedly send PING message with this interval (milli seconds). 5_000 is set by default.
- pool_size: how many connections for each gnatsd-cluster. 5 is set by default.

If you want to arrange them, the setting become like following.

```elixir
config :roulette, :connection,
  ring: [
    [host: "gnatsd-cluster1.example.org", port: 4222],
    [host: "gnatsd-cluster2.example.org", port: 4222]
  ],
  retry_interval: 2_000,
  ping_interval: 1_000,
  pool_size: 10

```

And you also can set configuration for each role (`Publisher` and `Subscriber`)

[TODO publisher config description here]

[TODO subscriber config description here]

### Gnat setting

This is default setting passed to Gnat.
See Gnat document for more detail.

```elixir
config :roulette, :connection,
  ring: [
    # your ring setting
  ],
  gnat: %{
    connection_timeout: 5_000,
    tls: false,
    ssl_opts: [],
    tcp_opts: [:binary, {:nodelay, true}]
  }

```

## Setup Supervisor

In your application bootstrap

```elixir
children = [
  {Roulette, [role: :both]},
  # ... setup other workers and supervisors
]
Supervisor.start_link(children, strategy: :one_for_one)
```

Put `Roulette` as one of children for your supervisor.

You can pass `role` parameter

- :both (default) - setup both `Publisher` and `Subscriber` connections
- :subscriber - setup `Subscriber` connections only
- :publisher - setup `Publisher` connections only

## Detailed description about Publish/Subscribe behaviour

## Ring Update: Take a service downtime or 3-phase deploy with Reserved-Ring

