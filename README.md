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
  ...
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

  def init(_opts) do
    Roulette.sub("foobar")
    {:ok, {}}
  end

  def handle_info({:pubsub_message, topic, msg, pid}, state) do
    # handle msg
    {:noreply, state}
  end

  def terminate(reason, state) do
    :ok
  end
```

Anywhere else you want to publish message in your app.

```elixir
Roulette.pub("foobar", data)
```

## Premised gnatsd Network Architecture


## Full Configuration Description


## Publish/Subscribe detailed behaviour

