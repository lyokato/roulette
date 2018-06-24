defmodule Roulette.Test.Supervisor do

  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      {Roulette.Test.PubSub1, []},
      {Roulette.Test.PubSub2, []}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
