defmodule Simple do
  @moduledoc false
  def start(_, args) do
    IO.inspect(args, label: "start args")
    System.halt(0)
  end

  def create_admin(username, password) when is_binary(username) and is_binary(password) do
    IO.puts("created admin #{username} with password: #{password}")
    :ok
  end
end
