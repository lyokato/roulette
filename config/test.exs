use Mix.Config

config :roulette, Roulette.Test.PubSub1,
  connection: [
    servers: [
      [host: "localhost", port: 4222]
    ],
    retry_interval: 1_000,
    pool_size: 5,
    show_debug_log: true
  ],
  publisher: [
    show_debug_log: true
  ],
  subscriber: [
    show_debug_log: true
  ]

