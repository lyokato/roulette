defmodule Roulette.Config do

  @moduledoc ~S"""
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

  |key|default|description|
  |:--|:--|:--|
  |role|:both|You can choose **:subscriber**, **:publisher**, or **:both**|
  |servers|required|servers list used as hash-ring|
  |pool_size|5|number of connections for each gnatsd-cluster|
  |ping_interval|5_000|sends PING message to gnatsd with this interval (milliseconds)|
  |max_ping_failure|2|if PONG doesn't return while this number of PING sends, Roulette disconnects the connection.|
  |max_retry|10|When it fails to send PUBLISH or SUBSCRIBE messages, it automatically retries until count of failure reaches to this number|
  |max_backoff|5_000|max duration(milliseconds) used to calculate backoff period|
  |base_backoff|10|base number used to calculate backoff period|
  |show_debug_log|false|if this is true, Roulette dumps many debug logs.|
  |subscription_restart|**:temporary**|You can choose **:temporary** or **:permanent**|

  ### role

  - :both (default) - setup both `Publisher` and `Subscriber` connections
  - :subscriber - setup `Subscriber` connections only
  - :publisher - setup `Publisher` connections only

  ### subscription_restart

  #### :temporary

  subscription-process sends EXIT message to consumer process when gnatsd-connection is disconnected.

  #### :permanent

  subscription-process try to keep subscription.
  when gnatsd-connection is disconnected, retry to sends SUBSCRIBE message through other connections.


  """

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
