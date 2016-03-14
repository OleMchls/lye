defmodule Lye do
  use Application

  def start(_type, _args) do
    :ranch.start_listener(:lye, 100,
      :ranch_ssl, [
        {:port, Application.get_env(:lye, :port)},
        {:certfile, Application.get_env(:lye, :certfile)},
        {:keyfile, Application.get_env(:lye, :keyfile)},
        {:alpn_preferred_protocols, [ "h2" ]},
      ], Lye.Connection, [])
  end
end
