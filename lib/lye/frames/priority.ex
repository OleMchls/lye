defmodule Lye.Frames.Priority do
  use GenEvent

  require Logger

  # Callbacks
  def handle_event({:frame, 0x2, sid, flags, body, connection}, settings) do
    Logger.debug inspect {:ok, :priority, sid, flags, body, connection}
    {:ok, settings}
  end

  def handle_event(_, settings), do: {:ok, settings}

  # def handle_call(:messages, settings) do
  #   {:ok, Enum.reverse(messages), []}
  # end
end
