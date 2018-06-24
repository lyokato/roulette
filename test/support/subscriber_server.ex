defmodule Roulette.Test.SubscriberServer do

  use GenServer

  def stack(pid) do
    GenServer.call(pid, :stack)
  end

  def sub(pid, topic) do
    GenServer.call(pid, {:sub, topic})
  end

  def pub(pid, topic, data) do
    GenServer.call(pid, {:pub, topic, data})
  end

  defstruct stack: []

  def start_link(name) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{stack: []}
    {:ok, state}
  end

  @impl GenServer
  def handle_info({:pubsub_message, topic, data, _pid}, state) do
    stack = [{topic, data} | state.stack]
    {:noreply, %{state | stack: stack}}
  end

  @impl GenServer
  def handle_call({:sub, topic}, _from, state) do
    result = Roulette.Test.PubSub1.sub(topic)
    {:reply, result, state}
  end
  def handle_call({:pub, topic, data}, _from, state) do
    result = Roulette.Test.PubSub1.pub(topic, data)
    {:reply, result, state}
  end
  def handle_call(:stack, _from, state) do
    {:reply, state.stack, state}
  end

end
