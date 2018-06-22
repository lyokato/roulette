defmodule Roulette.ClusterPool do

  alias Roulette.ClusterChooser
  alias Roulette.Config

  @type role :: :subscriber | :publisher

  @spec choose(
    module :: module,
    role   :: role,
    topic  :: String.t
  ) :: atom

  def choose(module, role, topic) do

    {host, port} =
      module
      |> ClusterChooser.choose(topic)
      |> Config.get_host_and_port()

    name(module, role, host, port)

  end

  @spec name(module :: module,
             role   :: role,
             host   :: String.t,
             port   :: pos_integer) :: atom

  def name(module, role, host, port) do
    Module.concat([module,
                   ClusterConnectionPool,
                   role,
                   "#{host}_#{port}"])
  end

end
