defmodule Simple do
  use Application

  @moduledoc false
  def start(_type, args) do
    IO.puts("Starting simple...")
    IO.inspect(args, label: "args")

    children = []
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def create_admin(username, password) when is_binary(username) and is_binary(password) do
    IO.inspect(System.get_env("RELEASE_DISTRIBUTION"), label: "RELEASE_DISTRIBUTION")
    IO.inspect(System.get_env("RELEASE_NAME"), label: "RELEASE_NAME")
    IO.inspect(System.get_env("PANTS"), label: "PANTS")
    IO.puts("created admin '#{username}' with password '#{password}'")
    :ok
  end

  def break_something do
    IO.puts("broke something!")
  end
end
