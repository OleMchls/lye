defmodule Lye.Frames.Headers do
  use GenEvent

  require Logger

  # Callbacks
  def init(initial_table_size) do
    HPack.Table.start_link(initial_table_size)
  end

  # +---------------+
  # |Pad Length? (8)|
  # +-+-------------+-----------------------------------------------+
  # |E|                 Stream Dependency? (31)                     |
  # +-+-------------+-----------------------------------------------+
  # |  Weight? (8)  |
  # +-+-------------+-----------------------------------------------+
  # |                   Header Block Fragment (*)                 ...
  # +---------------------------------------------------------------+
  # |                           Padding (*)                       ...
  # +---------------------------------------------------------------+
  # Figure 7: HEADERS Frame Payload
  def handle_event({:frame, 0x1, sid, flags, body, connection}, ctx) do
    Logger.debug inspect {:ok, :headers, sid, flags, body, connection}
    # Lye.Connection.send_frame(connection, {0x1, sid, flags, body})
    {:ok, ctx}
  end

  def handle_event(_, ctx), do: {:ok, ctx}

  # def handle_call(:messages, settings) do
  #   {:ok, Enum.reverse(messages), []}
  # end
end
