defmodule Lye.Connection.Settings do
  defstruct [
    header_table_size: 4096,
    enable_push: 1,
    max_concurrent_streams: 100,
    initial_window_size: 65535,
    max_frame_size: 16384,
    max_header_list_size: :infinity
  ]
end
