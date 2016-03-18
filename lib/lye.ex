defmodule Lye do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      ranch
      # Define workers and child supervisors to be supervised
      # worker(Banana.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Lye.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def ranch do
    :ranch.child_spec(:lye, 100,
      :ranch_ssl, [
        {:port, Application.get_env(:lye, :port)},
        {:certfile, Application.get_env(:lye, :certfile)},
        {:keyfile, Application.get_env(:lye, :keyfile)},
        {:alpn_preferred_protocols, [ "h2" ]},
      ], Lye.Connection, [])
  end
end
