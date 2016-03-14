defmodule Lye.Parser do

  @init_str << 0x505249202a20485454502f322e300d0a0d0a534d0d0a0d0a::192 >>

  def handshake(recv) do
    {:ok, @init_str} = recv.(byte_size(@init_str))
    :ok
  end

  def parse_frame(recv) do
    {:ok, <<
      length::24,
      type::8, flags::8,
      0::1, sid::31
    >>} = recv.(9)
    {:ok, body} = recv.(length)
    {:ok, type, flags, sid, body}
  end
end
