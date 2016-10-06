defmodule Lye.Stream do
  use GenServer
  use Bitwise

  @type t :: %__MODULE__{}
  defstruct id: nil, connection: nil, exclusive: false, dependency: nil, weight: 16, adapter: nil

  def create(connection_pid, stream_id, adapter \\ Lye.Connection) do
    %Lye.Stream{id: stream_id, connection: connection_pid, adapter: adapter}
  end

  def start_link(stream, opts \\ []) do
    GenServer.start_link(__MODULE__, stream, opts)
  end

  def process_frame(pid, type, flags, body) do
    GenServer.cast(pid, {:process_frame, type, flags, body})
  end

  def handle_cast({:process_frame, type, flags, body}, stream) do
    IO.puts "[Stream #{stream.id}] recv frame type #{type}"
    {:noreply, handle_frame(stream, type, flags, body)}
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
  def handle_frame(stream, 0x1, flags, << pad_len::8, rest::binary >>) when flags &&& 0b1000 > 1 do
    IO.inspect "Figure 7 (/w padding): HEADERS Frame Payload"
    handle_frame(stream, 0x1, bxor(flags, 0x8), remove_padding(pad_len, rest))
  end
  def handle_frame(stream, 0x1, flags, << exclusive::1, dependency::31, rest::binary >>) do
    # if flags &&& 0x
    IO.inspect "Figure 7: HEADERS Frame Payload – Flags #{Integer.to_string(flags,2)}"
    stream
  end

  defp remove_padding(pad_len, binary), do: binary_part(binary, 0, byte_size(binary)-pad_len)

  # +-+-------------------------------------------------------------+
  # |E|                  Stream Dependency (31)                     |
  # +-+-------------+-----------------------------------------------+
  # |   Weight (8)  |
  # +-+-------------+
  # Figure 8: PRIORITY Frame Payload
  def handle_frame(stream, 0x2, flags, << exclusive::1, dependency::31, weight::8 >>) do
    IO.inspect "Figure 8: PRIORITY Frame Payload"
    %Lye.Stream{stream | exclusive: exclusive == 1, dependency: dependency, weight: weight}
  end

  #  +-------------------------------+
  #  |       Identifier (16)         |
  #  +-------------------------------+-------------------------------+
  #  |                        Value (32)                             |
  #  +---------------------------------------------------------------+
  # Figure 10: Setting Format
  def handle_frame(stream, 0x4, 0x1, _body), do: stream #["nothing (client acks settings)"]}
  def handle_frame(stream, 0x4, 0x0, body) do
    IO.inspect "XXX Figure 10: Setting Format"
    actions = parse_settings(body, [])
    |> Enum.map(fn({key, value}) -> stream.adapter.update_setting(stream.connection, key, value) end)
    stream.adapter.send_frame(stream.connection, {0x4, 0, 0x1, << >>})
    stream
  end

  defp parse_settings(<< >>, settings), do: Enum.reverse(settings)
  defp parse_settings(<< identifier::16, value::32, rest::binary >>, settings) do
    parse_settings(rest, [{identifier, value} | settings])
  end
end
