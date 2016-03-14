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
    {:ok, compression_ctx} = HPack.Table.start_link(4096)

    loop(socket, transport, compression_ctx, %Lye.Connection.Settings{})
  end

  def loop(socket, transport, compression_ctx, settings) do
    {:ok, type, flags, sid, body} = Parser.parse_frame(fn(len) -> transport.recv(socket, len, :infinity) end)

    Logger.debug inspect {:ok, type, sid, flags, body}
    # case transport.recv(socket, 0, 5000) do
    #   {:ok, data} ->
    #     transport.send(socket, data)
    #     loop(socket, transport);
    #   _ ->
    #     :ok = transport.close(socket)
    # end
    loop(socket, transport, compression_ctx, settings)
  end
end
