defmodule Roulette.NatsClient do

  # Most of this code is borrowed from Gnat.ex
  # We would like to put some experimental arrange into it.

  use GenServer
  require Logger
  alias Gnat.{Command, Parser, Handshake}

  @type message :: %{topic: String.t, body: String.t, reply_to: String.t}

  @default_connection_settings %{
    host: 'localhost',
    port: 4222,
    tcp_opts: [:binary],
    connection_timeout: 3_000,
    ssl_opts: [],
    tls: false,
  }

  @spec start_link(map(), keyword()) :: GenServer.on_start
  def start_link(connection_settings \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, connection_settings, opts)
  end

  @spec stop(GenServer.server) :: :ok
  def stop(pid), do: GenServer.stop(pid)

  @spec sub(GenServer.server, pid(), String.t, keyword()) :: {:ok, non_neg_integer()}
  def sub(pid, subscriber, topic, opts \\ []), do: GenServer.call(pid, {:sub, subscriber, topic, opts})

  @spec pub(GenServer.server, String.t, binary(), keyword()) :: :ok
  def pub(pid, topic, message, opts \\ []), do: GenServer.call(pid, {:pub, topic, message, opts})

  @spec request(GenServer.server, String.t, binary(), keyword()) ::
    {:ok, message} | {:error, :timeout}
  def request(pid, topic, body, opts \\ []) do

    receive_timeout = Keyword.get(opts, :receive_timeout, 60_000)

    inbox = gen_inbox()

    {:ok, subscription} =
      GenServer.call(pid, {:request, %{recipient: self(), inbox: inbox, body: body, topic: topic}})

    receive do
      {:msg, %{topic: ^inbox} = msg} -> {:ok, msg}
      after receive_timeout ->
        :ok = unsub(pid, subscription)
        {:error, :timeout}
    end

  end

  defp gen_inbox() do
    random  = :crypto.strong_rand_bytes(12)
    encoded = Base.encode64(random)
    "INBOX-#{encoded}"
  end

  @spec unsub(GenServer.server, non_neg_integer(), keyword()) :: :ok
  def unsub(pid, sid, opts \\ []), do: GenServer.call(pid, {:unsub, sid, opts})

  def ping(pid) do
    GenServer.call(pid, {:ping, self()})
    # We don't like to block caller process here
    #receive do
    #  :pong -> :ok
    #after
    #  3_000 -> {:error, "No PONG response after 3 sec"}
    #end
  end

  @impl GenServer
  def init(connection_settings) do
    connection_settings = Map.merge(@default_connection_settings, connection_settings)
    case Handshake.connect(connection_settings) do
      {:ok, socket} ->
        parser = Parser.new
        {:ok, %{socket: socket, connection_settings: connection_settings, next_sid: 1, receivers: %{}, parser: parser}}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_info({:tcp, socket, data}, %{socket: socket} = state) do
    data_packets = receive_additional_tcp_data(socket, [data], 10)
    new_state = Enum.reduce(data_packets, state, fn(data, %{parser: parser} = state) ->
      {new_parser, messages} = Parser.parse(parser, data)
      new_state = %{state | parser: new_parser}
      Enum.reduce(messages, new_state, &process_message/2)
    end)
    {:noreply, new_state}
  end
  def handle_info({:ssl, socket, data}, state) do
    handle_info({:tcp, socket, data}, state)
  end
  def handle_info({:tcp_closed, _}, state) do
    {:stop, "connection closed", %{state|socket: nil}}
  end
  def handle_info({:ssl_closed, _}, state) do
    {:stop, "connection closed", %{state|socket: nil}}
  end
  def handle_info({:tcp_error, _, reason}, state) do
    {:stop, "tcp transport error #{inspect(reason)}", state}
  end
  def handle_info(other, state) do
    Logger.error "#{__MODULE__} received unexpected message: #{inspect other}"
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:sub, receiver, topic, opts}, _from, %{next_sid: sid} = state) do

    sub = Command.build(:sub, topic, sid, opts)

    case socket_write(state, sub) do

      :ok ->
        next_state = state
                     |> add_subscription_to_state(sid, receiver)
                     |> Map.put(:next_sid, sid + 1)
        {:reply, {:ok, sid}, next_state}

      {:error, reason} ->
        Logger.error "#{__MODULE__} failed to write on socket: #{inspect reason}"
        {:stop, :shutdown, state}

    end
  end

  def handle_call({:pub, topic, message, opts}, from, state) do

    commands = [Command.build(:pub, topic, message, opts)]
    froms = [from]
    {commands, froms} = receive_additional_pubs(commands, froms, 10)

    case socket_write(state, commands) do

      :ok ->
        Enum.each(froms, fn(from) -> GenServer.reply(from, :ok) end)
        {:noreply, state}

      {:error, reason} ->
        Logger.error "#{__MODULE__} failed to write on socket: #{inspect reason}"
        {:stop, :shutdown, state}

    end
  end

  def handle_call({:unsub, sid, opts}, _from, %{receivers: receivers} = state) do
    case Map.has_key?(receivers, sid) do

      false -> {:reply, :ok, state}

      true ->
        command = Command.build(:unsub, sid, opts)
        case socket_write(state, command) do

          :ok ->
            state = cleanup_subscription_from_state(state, sid, opts)
            {:reply, :ok, state}

          {:error, reason} ->
            Logger.error "#{__MODULE__} failed to write on socket: #{inspect reason}"
            {:stop, :shutdown, state}

        end
    end
  end

  def handle_call({:ping, pinger}, _from, state) do
    case socket_write(state, "PING\r\n") do

      :ok ->
        {:reply, :ok, Map.put(state, :pinger, pinger)}

      {:error, reason} ->
        Logger.error "#{__MODULE__} failed to write on socket: #{inspect reason}"
        {:stop, :shutdown, state}

    end
  end

  @impl GenServer
  def terminate(_reason, %{socket: nil}) do
    :ok
  end
  def terminate(_reason, state) do
    socket_close(state)
    :ok
  end

  defp socket_close(%{socket: socket, connection_settings: %{tls: true}}), do: :ssl.close(socket)
  defp socket_close(%{socket: socket}), do: :gen_tcp.close(socket)

  defp socket_write(%{socket: socket, connection_settings: %{tls: true}}, iodata) do
    :ssl.send(socket, iodata)
  end
  defp socket_write(%{socket: socket}, iodata), do: :gen_tcp.send(socket, iodata)

  defp add_subscription_to_state(%{receivers: receivers} = state, sid, pid) do
    receivers = Map.put(receivers, sid, %{recipient: pid, unsub_after: :infinity})
    %{state | receivers: receivers}
  end

  defp cleanup_subscription_from_state(%{receivers: receivers} = state, sid, []) do
    receivers = Map.delete(receivers, sid)
    %{state | receivers: receivers}
  end
  defp cleanup_subscription_from_state(%{receivers: receivers} = state, sid, [max_messages: n]) do
    receivers = put_in(receivers, [sid, :unsub_after], n)
    %{state | receivers: receivers}
  end

  defp process_message({:msg, topic, sid, reply_to, body}, state) do
    if is_nil(state.receivers[sid]) do
      # This can be caused on nominal situation
      # Logger.error "#{__MODULE__} got message for sid #{sid}, but that is no longer registered"
      Logger.info "#{__MODULE__} got message for sid #{sid}, but that is no longer registered"
      state
    else
      send state.receivers[sid].recipient, {:msg, %{topic: topic, body: body, reply_to: reply_to, gnat: self()}}
      update_subscriptions_after_delivering_message(state, sid)
    end
  end
  defp process_message(:ping, state) do
    socket_write(state, "PONG\r\n")
    state
  end
  defp process_message(:pong, state) do
    send state.pinger, :pong
    state
  end
  defp process_message({:error, message}, state) do
    :error_logger.error_report([
      type: :gnat_error_from_broker,
      message: message,
    ])
    state
  end

  defp receive_additional_pubs(commands, froms, 0), do: {commands, froms}
  defp receive_additional_pubs(commands, froms, how_many_more) do
    receive do
      {:"$gen_call", from, {:pub, topic, message, opts}} ->
        commands = [Command.build(:pub, topic, message, opts) | commands]
        froms = [from | froms]
        receive_additional_pubs(commands, froms, how_many_more - 1)
    after
      0 -> {commands, froms}
    end
  end

  def receive_additional_tcp_data(_socket, packets, 0), do: Enum.reverse(packets)
  def receive_additional_tcp_data(socket, packets, n) do
    receive do
      {:tcp, ^socket, data} ->
        receive_additional_tcp_data(socket, [data | packets], n - 1)
      after
        0 -> Enum.reverse(packets)
    end
  end

  defp update_subscriptions_after_delivering_message(%{receivers: receivers} = state, sid) do
    receivers = case get_in(receivers, [sid, :unsub_after]) do
                  :infinity -> receivers
                  1 -> Map.delete(receivers, sid)
                  n -> put_in(receivers, [sid, :unsub_after], n - 1)
                end
    %{state | receivers: receivers}
  end
end
