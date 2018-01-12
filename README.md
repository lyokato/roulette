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

## Usage Example

Configuration

```elixir
config :roulette, :connection,
  hosts: [
    "gnatsd-cluster1.example.org",
    "gnatsd-cluster2.example.org"
  ],
  port: 4222

config :roulette, :subscriber,
  enabled: true,
  restart: :temporary

config :roulette, :publisher,
  enabled: true
```

In your application bootstrap

```elixir
children = [
  {Roulette, []},
  ...
]
Supervisor.start_link(children, )
```

Server process in your app.

```exlixir
defmodule YourSession do

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Roulette.sub("foobar")
    {:ok, {}}
  end

  def handle_info({:subscribed_message, topic, msg, pid}, state) do
    # handle msg
    {:noreply, state}
  end

  def terminate(reason, state) do
    Roulette.unsub("foobar")
    :ok
  end
```

Anywhere else in your app.

```elixir
Roulette.pub("foobar", topic)
```


