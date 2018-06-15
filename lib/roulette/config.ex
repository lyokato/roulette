defmodule Roulette.Config do

  @default_port 4222

  @type host :: %{
      required(:host) => String.t,
      required(:port) => pos_integer
    }

  @type nats_config :: %{
      required(:host)               => String.t,
      required(:port)               => pos_integer,
      optional(:connection_timeout) => pos_integer,
      optional(:tls)                => boolean,
      optional(:ssl_opts)           => keyword,
      optional(:tcp_opts)           => keyword
    }

  @default_connection_values [
      ring: [],
      reserved_ring: [],
      ping_interval: 5_000,
      max_ping_failure: 2,
      show_debug_log: false,
      pool_size: 5,
      nats: %{
        connection_timeout: 5_000,
        tls: false,
        ssl_opts: [],
        tcp_opts: [:binary, {:nodelay, true}]
      }
    ]

  @nats_config_keys [:connection_timeout, :tls, :ssl_opts, :tcp_opts]

  @default_publisher_values [
      max_retry: 10,
      max_backoff: 5_000,
      base_backoff: 10
    ]

  @default_subscriber_values [
      max_retry: 10,
      max_backoff: 5_000,
      base_backoff: 10,
      show_debug_log: false,
      restart: :temporary
    ]

  def get(type, key) do
    get_category(type) |> Keyword.fetch!(key)
  end

  @spec merge_nats_config(host) :: nats_config
  def merge_nats_config(host) do
    nats_config = get(:connection, :nats)
    @nats_config_keys
    |> Enum.reduce(host, &(Map.put(&2, &1, Map.fetch!(nats_config, &1))))
  end

  defp default_values(:subscriber) do
    @default_subscriber_values
  end
  defp default_values(:publisher) do
    @default_publisher_values
  end
  defp default_values(:connection) do
    @default_connection_values
  end

  defp get_category(type) do
    name = Module.concat(Roulette.Config, "#{type}")
    case FastGlobal.get(name, nil) do
      nil ->
        val = get_raw_category(type)
        FastGlobal.put(name, val)
        val
      val -> val
    end
  end

  defp get_raw_category(type) do
    defaults = default_values(type)
    case Application.get_env(:roulette, type) do
      nil -> defaults
      val -> Keyword.merge(defaults, val)
    end
  end

  def get_host_and_port(target) when is_binary(target) do
    {target, @default_port}
  end
  def get_host_and_port(target) do
    host = Keyword.fetch!(target, :host)
    port = Keyword.get(target, :port, @default_port)
    {host, port}
  end

end
