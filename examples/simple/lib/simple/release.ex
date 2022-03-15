defmodule Simple.Release do
  @moduledoc false

  @app :simple

  def create_admin(username, password) do
    start_app()
    Simple.create_admin(username, password)
  end

  def migrate do
    IO.puts("migrating... (this will crash as nothing is setup in this example)")
    load_app()
    configure_repo()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
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

  defp configure_repo do
    config = Vapor.load!(Simple.Config)
    Application.put_env(@app, Simple.Repo, Keyword.new(config.repo))
  end
end
