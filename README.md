# Lye
Your super fast (I hope it will be super fast), reliable, modular, extensible HTTP/2 web server in Elixir.

## Usage
Lye has two ways of interacting with HTTP traffic:

### Plug (high level api)

```elixir
defmodule MyPlug do
  import Plug.Conn

  def init(options) do: options

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Hello world")
  end
end
```

```elixir
{:ok, _} = Lye::Plug.https MyPlug, []
{:ok, #PID<...>}
```

### GenEvent (low level api)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add lye to your list of dependencies in `mix.exs`:

        def deps do
          [{:lye, "~> 0.0.1"}]
        end

  2. Ensure lye is started before your application:

        def application do
          [applications: [:lye]]
        end
