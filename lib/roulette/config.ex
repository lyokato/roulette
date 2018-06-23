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
      servers: [],
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

  def get(module, type, key) do
    name = category_name(module, type)
    case FastGlobal.get(name, nil) do
      nil -> raise "<Roulette.Config> Unknown type: #{type}"
      cat -> case Keyword.get(cat, key) do
        nil -> raise "<Roulette.Config> Unknown key: #{key}"
        val -> val
      end
    end
  end

  @spec merge_nats_config(module, host) :: nats_config
  def merge_nats_config(module, host) do
    nats_config = get(module, :connection, :nats)
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

  def get_host_and_port(target) when is_binary(target) do
    {target, @default_port}
  end
  def get_host_and_port(target) do
    host = Keyword.fetch!(target, :host)
    port = Keyword.get(target, :port, @default_port)
    {host, port}
  end

  @doc ~S"""
  Load handler's configuration.
  """
  @spec load(module, any) :: {Keyword.t, Keyword.t, Keyword.t}
  def load(module, opts) do
    conf = opts
           |> Keyword.fetch!(:otp_app)
           |> Application.get_env(module, [])

    conn = load_category_conf(conf, :connection)
    pub  = load_category_conf(conf, :publisher)
    sub  = load_category_conf(conf, :subscriber)
    {conn, pub, sub}
  end

  def store(module, {conn, pub, sub}) do
    store_category_conf(module, :connection, conn)
    store_category_conf(module, :publisher,  pub)
    store_category_conf(module, :subscriber, sub)
    :ok
  end

  defp store_category_conf(module, type, val) do
    module |> category_name(type) |> FastGlobal.put(val)
    :ok
  end

  defp load_category_conf(config, type) do
    defaults = default_values(type)
    case Keyword.get(config, :connection) do
      nil -> defaults
      val -> Keyword.merge(defaults, val)
    end
  end

  defp category_name(module, type) do
    Module.concat([module, Config, "#{type}"])
  end

end
