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

  @type config_key :: :servers
                    | :ping_interval
                    | :max_ping_failure
                    | :show_debug_log
                    | :pool_size
                    | :max_retry
                    | :max_backoff
                    | :base_backoff
                    | :subscription_restart
                    | :nats

  @default_values [
      role: :both,
      servers: [],
      ping_interval: 5_000,
      max_ping_failure: 2,
      show_debug_log: false,
      pool_size: 5,
      max_retry: 10,
      max_backoff: 5_000,
      base_backoff: 10,
      subscription_restart: :temporary,
      nats: %{
        connection_timeout: 5_000,
        tls: false,
        ssl_opts: [],
        tcp_opts: [:binary, {:nodelay, true}]
      }
    ]


  @nats_config_keys [:connection_timeout, :tls, :ssl_opts, :tcp_opts]

  @spec get(module, config_key) :: term
  def get(module, key) do
    name = config_name(module)
    case FastGlobal.get(name, nil) do
      nil -> raise "<Roulette.Config> Config not saved for #{module}, maybe Roulette.Supervisor has not completed setup"
      conf -> case Keyword.get(conf, key) do
        nil -> Keyword.fetch!(@default_values, key)
        val -> val
      end
    end
  end

  @spec merge_nats_config(module, host) :: nats_config
  def merge_nats_config(module, host) do
    nats_config = get(module, :nats)
    @nats_config_keys
    |> Enum.reduce(host, &(Map.put(&2, &1, Map.fetch!(nats_config, &1))))
  end

  @spec get_host_and_port(binary | Keyword.t) :: {binary, pos_integer}
  def get_host_and_port(target) when is_binary(target) do
    {target, @default_port}
  end
  def get_host_and_port(target) do
    host = Keyword.fetch!(target, :host)
    port = Keyword.get(target, :port, @default_port)
    {host, port}
  end

  @spec load(module, any) :: Keyword.t
  def load(module, opts) do
    opts
    |> Keyword.fetch!(:otp_app)
    |> Application.get_env(module, [])
  end

  @spec store(module, Keyword.t) :: :ok
  def store(module, val) do
    name = config_name(module)
    FastGlobal.put(name, val)
    :ok
  end

  defp config_name(module) do
    Module.concat(module, Config)
  end

end
