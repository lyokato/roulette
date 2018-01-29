use Mix.Config

config :roulette, :connection,
  ring: [
    [host: "localhost", port: 4222],
  ],
  retry_interval: 1_000,
  pool_size: 5,
  gnat: %{
    connection_timeout: 5_000,
    tls: false,
    ssl_opts: [],
    tcp_opts: [:binary, {:nodelay, true}]
  }

config :roulette, :subscriber,
  max_retry: 5,
  retry_interval: 2_000,
  restart: :temporary

config :roulette, :publisher,
  max_retry: 5
