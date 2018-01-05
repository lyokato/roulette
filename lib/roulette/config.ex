defmodule Roulette.Config do

  @type host :: %{
      required(:host) => String.t,
      required(:port) => pos_integer
    }

  @type gnat_config :: %{
      required(:host)               => String.t,
      required(:port)               => pos_integer,
      optional(:connection_timeout) => pos_integer,
      optional(:tls)                => boolean,
      optional(:ssl_opts)           => keyword,
      optional(:tcp_opts)           => keyword
    }

  @default_connection_values %{
      hosts: [],
      port: 4222,
      retry_interval: 1_000,
      max_retry: 5,
      pool_size: 5,
      gnat: %{
        connection_timeout: 5_000,
        tls: false,
        ssl_opts: [],
        tcp_opts: [:binary, {:nodelay, true}]
      }
    }

  @gnat_config_keys [:connection_timeout, :tls, :ssl_opts, :tcp_opts]

  @default_publisher_values %{
      enabled: false,
      max_retry: 5
    }

  @default_subscriber_values %{
      enabled: false,
      max_retry: 5,
      retry_interval: 2_000,
      restart: :temporary
    }

  def get(type, key) do
    get_category(type) |> Map.fetch!(key)
  end

  @spec merge_gnat_config(host) :: gnat_config
  def merge_gnat_config(host) do
    gnat_config = get(:connection, :gnat)
    @gnat_config_keys
    |> Enum.reduce(host, &(Map.put(&2, &1, Map.fetch!(gnat_config, &1))))
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
      val -> Map.merge(defaults, val)
    end
  end

end
