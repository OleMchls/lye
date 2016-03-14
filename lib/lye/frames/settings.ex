defmodule Lye.Frames.Settings do
  use GenEvent

  require Logger

  # Callbacks
  def handle_event({:frame, 0x4, sid, flags, body, connection}, settings) do
    Logger.debug inspect {:ok, :settings, sid, flags, body, connection}
    {:ok, settings}
  end

  def handle_event(_, settings), do: {:ok, settings}

  # def handle_call(:messages, settings) do
  #   {:ok, Enum.reverse(messages), []}
  # end
end
