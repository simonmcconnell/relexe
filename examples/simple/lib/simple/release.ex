defmodule Simple.Release do
  @moduledoc false

  @app :simple

  def create_admin(username, password) do
    start_app()
    Simple.create_admin(username, password)
  end

  def migrate do
    IO.puts("migrating...")
  end

  def rollback(repo, version) do
    IO.puts("rolling back #{repo} to #{version}")
  end

  defp start_app do
    IO.puts("starting app")
    load_app()
    Application.put_env(@app, :minimal, true)
    Application.ensure_all_started(@app)
  end

  defp load_app do
    IO.puts("loading app")
    Application.load(@app)
  end
end
