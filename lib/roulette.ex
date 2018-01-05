defmodule Roulette do

  @moduledoc """
  Documentation for Roulette.
  """

  @spec pub(String.t, any) :: :ok | :error
  def pub(topic, data) do
    Roulette.Publisher.pub(topic, data)
  end

  @spec sub(String.t) :: Supervisor.on_start_child
  def sub(topic) do
    Roulette.Subscriber.sub(topic)
  end

  @spec unsub(pid | String.t) :: :ok
  def unsub(pid_or_topic) do
    Roulette.Subscriber.unsub(pid_or_topic)
  end

end
