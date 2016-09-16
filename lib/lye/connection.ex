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

    {:ok, sender} = Task.start_link(__MODULE__, :send_loop, [socket, transport])
    {:ok, receiver} = Task.start_link(__MODULE__, :recv_loop, [socket, transport, self()])

    # TODO: find better / cleaner way to init connection settings
    send(sender, {:frame, build_frame(0x4, 0, 0, <<
      0x3::16, 100::32,
      0x4::16, 65535::32
    >>)})

    # This time, we don't pass any argument because
    # the argument will be given when we start the child
    children = [
      Supervisor.Spec.worker(Lye.Stream, [], restart: :transient)
    ]

    # Start the supervisor with our one child
    {:ok, sup_pid} = Supervisor.start_link(children, strategy: :simple_one_for_one)

    %{settings: %Lye.Connection.Settings{}, sender: sender, stream_handler_sup: sup_pid, stream_map: %{}}
  end

  def send_frame(pid, {type, sid, flags, body}) do
    GenServer.cast(pid, {:send_frame, build_frame(type, sid, flags, body) })
  end

  def recv_frame(pid, {type, sid, flags, body}) do
    GenServer.call(pid, {:recv_frame, type, sid, flags, body})
  end

  def handle_cast({:send_frame, frame}, state) do
    send state.sender, {:frame, frame}
    {:noreply, state}
  end

  def handle_call({:recv_frame, type, sid, flags, body}, _from, state) do
    stream_map = Map.put_new_lazy(state.stream_map, sid, fn ->
      {:ok, wrk_pid} = Supervisor.start_child(state.stream_handler_sup, [self(), sid])
      wrk_pid
    end)
    {:ok, stream_pid} = Map.fetch(stream_map, sid)
    Lye.Stream.process_frame(stream_pid, type, flags, body)
    {:reply, :ok, state}
  end

  def recv_loop(socket, transport, connection) do
    {:ok, type, flags, sid, body} = Parser.parse_frame(fn(len) -> transport.recv(socket, len, :infinity) end)
    :ok = recv_frame(connection, {type, sid, flags, body})
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
  defp build_frame(type, sid, flags, body), do: << byte_size(body)::24, type::8, flags::8, 0::1, sid::31, body::binary >>
end
