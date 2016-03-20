defmodule Lye.Connection do

  use GenServer
  require Logger

  @behaviour :ranch_protocol

  alias Lye.Parser

  def start_link(ref, socket, transport, opts) do
    GenServer.start_link(__MODULE__, [ref, socket, transport, opts])
  end

  def init([ref, socket, transport, opts]) do
    # little hack: defer loop_init until init has returned and thus ranch
    # started the tcp server otherweise we would end up in a deadlock ranch
    # waiting to return and init waiting to ack the connection.
    GenServer.cast(self(), {:loop_init, [ref, socket, transport, opts]})
    {:ok, []}
  end

  def handle_cast({:loop_init, [ref, socket, transport, opts]}, _) do
    {:noreply, loop_init(ref, socket, transport, opts)}
  end

  def loop_init(ref, socket, transport, _opts \\ []) do
    :ok = :ranch.accept_ack(ref)
    :ok = Parser.handshake(fn(len) -> transport.recv(socket, len, 10) end)
    {:ok, events} = GenEvent.start_link([])

    GenEvent.add_handler(events, Lye.Frames.Headers, [4096])
    GenEvent.add_handler(events, Lye.Frames.Priority, [])
    GenEvent.add_handler(events, Lye.Frames.Settings, [])

    {:ok, sender} = Task.start_link(__MODULE__, :send_loop, [socket, transport])
    {:ok, receiver} = Task.start_link(__MODULE__, :recv_loop, [socket, transport, self()])

    %{settings: %Lye.Connection.Settings{}, sender: sender, events: events}
  end

  # +-----------------------------------------------+
  # |                 Length (24)                   |
  # +---------------+---------------+---------------+
  # |   Type (8)    |   Flags (8)   |
  # +-+-------------+---------------+-------------------------------+
  # |R|                 Stream Identifier (31)                      |
  # +=+=============================================================+
  # |                   Frame Payload (0...)                      ...
  # +---------------------------------------------------------------+
  # Figure 1: Frame Layout
  def send_frame(pid, {type, sid, flags, body}) do
    GenServer.cast(pid, {:send_frame, << byte_size(body)::24, type::8, flags::8, 0::1, sid::31, body::binary >> })
  end

  def recv_frame(pid, {type, sid, flags, body}) do
    GenServer.cast(pid, {:recv_frame, type, sid, flags, body})
  end

  def handle_cast({:send_frame, frame}, state) do
    send state.sender, {:frame, frame}
    {:noreply, state}
  end

  def handle_cast({:recv_frame, type, sid, flags, body}, state) do
    GenEvent.notify(state.events, {:frame, type, sid, flags, body, self()})
    {:noreply, state}
  end

  def recv_loop(socket, transport, connection) do
    {:ok, type, flags, sid, body} = Parser.parse_frame(fn(len) -> transport.recv(socket, len, :infinity) end)
    recv_frame(connection, {type, sid, flags, body})

    # case transport.recv(socket, 0, 5000) do
    #   {:ok, data} ->
    #     transport.send(socket, data)
    #     recv_loop(socket, transport);
    #   _ ->
    #     :ok = transport.close(socket)
    # end
    recv_loop(socket, transport, connection)
  end

  def send_loop(socket, transport) do
    receive do
      {:frame, frame} ->
        transport.send(socket, frame)
        send_loop(socket, transport)
      # {:world, msg} -> "won't match"
    end
  end
end
