defmodule Lye.Connection do

  require Logger

  @behaviour :ranch_protocol

  alias Lye.Parser

  def start_link(ref, socket, transport, opts) do
    pid = spawn_link(__MODULE__, :init, [ref, socket, transport, opts])
    {:ok, pid}
  end

  def init(ref, socket, transport, _opts \\ []) do
    :ok = :ranch.accept_ack(ref)
    :ok = Parser.handshake(fn(len) -> transport.recv(socket, len, 10) end)
    {:ok, events} = GenEvent.start_link([])

    GenEvent.add_handler(events, Lye.Frames.Headers, [4096])
    GenEvent.add_handler(events, Lye.Frames.Priority, [])
    GenEvent.add_handler(events, Lye.Frames.Settings, [])

    {:ok, sender} = Task.start_link(__MODULE__, :send_loop, [socket, transport])
    Task.start_link(__MODULE__, :recv_loop, [socket, transport, %Lye.Connection.Settings{}, events, sender])

    # TODO: replace with GenServer
    loop([])
  end

  def loop(state) do
    loop(state)
  end

  def recv_loop(socket, transport, settings, event_bus, connection) do
    {:ok, type, flags, sid, body} = Parser.parse_frame(fn(len) -> transport.recv(socket, len, :infinity) end)

    GenEvent.notify(event_bus, {:frame, type, sid, flags, body, connection})
    # case transport.recv(socket, 0, 5000) do
    #   {:ok, data} ->
    #     transport.send(socket, data)
    #     recv_loop(socket, transport);
    #   _ ->
    #     :ok = transport.close(socket)
    # end
    recv_loop(socket, transport, settings, event_bus, connection)
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
