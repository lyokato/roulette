use Mix.Config

config :roulette, Roulette.Test.PubSub1,
  role: :both,
  servers: [
    [host: "localhost", port: 4222]
  ],
  subscription_restart: :permanent,
  retry_interval: 1_000,
  pool_size: 5,
  show_debug_log: true

config :roulette, Roulette.Test.PubSub2,
  role: :both,
  servers: [
    [host: "localhost", port: 4222],
    [host: "localhost", port: 4223]
  ],
  retry_interval: 1_000,
  pool_size: 5,
  show_debug_log: true
