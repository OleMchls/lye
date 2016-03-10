# Lye
Your super fast (I hope it will be super fast), reliable, modular, extensible HTTP/2 web server in Elixir.

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
