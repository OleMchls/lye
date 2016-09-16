defmodule Lye.Stream do
  use GenServer

  # @type t :: %__MODULE__{}
  # defstruct [:id, :headers, :body, :header_compression_ctx]

  def start_link(connection_pid, stream_id, opts \\ []) do
    GenServer.start_link(__MODULE__, %{connection: connection_pid, stream: stream_id}, opts)
  end

  # @spec process_frame(t, integer, binary, String.t) :: t
  def process_frame(pid, type, flags, body) do
    GenServer.cast(pid, {:process_frame, type, flags, body})
  end

  def handle_cast({:process_frame, type, flags, body}, state) do
    IO.puts "[Stream #{state.stream}] recv frame type #{type}"

    case handle_frame(type, flags, body) do
      {:send_frame, frame} ->
        Lye.Connection.send_frame(state.connection, frame)
      other -> IO.inspect other
    end

    {:noreply, state}
  end

  #  +---------------+
  #  |Pad Length? (8)|
  #  +-+-------------+-----------------------------------------------+
  #  |E|                 Stream Dependency? (31)                     |
  #  +-+-------------+-----------------------------------------------+
  #  |  Weight? (8)  |
  #  +-+-------------+-----------------------------------------------+
  #  |                   Header Block Fragment (*)                 ...
  #  +---------------------------------------------------------------+
  #  |                           Padding (*)                       ...
  #  +---------------------------------------------------------------+
  # Figure 7: HEADERS Frame Payload
  def handle_frame(0x1, flags, body) do
    "Figure 7: HEADERS Frame Payload"
  end

  # +-+-------------------------------------------------------------+
  # |E|                  Stream Dependency (31)                     |
  # +-+-------------+-----------------------------------------------+
  # |   Weight (8)  |
  # +-+-------------+
  # Figure 8: PRIORITY Frame Payload
  def handle_frame(0x2, flags, body) do
    "Figure 8: PRIORITY Frame Payload"
  end

  #  +-------------------------------+
  #  |       Identifier (16)         |
  #  +-------------------------------+-------------------------------+
  #  |                        Value (32)                             |
  #  +---------------------------------------------------------------+
  # Figure 10: Setting Format
  def handle_frame(0x4, 0x1, body), do: "nthing (client acks settings)"
  def handle_frame(0x4, flags, body) do
    IO.inspect "XXX Figure 10: Setting Format"
    {:send_frame, {0x4, 0, 0x1, << >>}}
  end
end
