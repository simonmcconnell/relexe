defmodule Simple.MixProject do
  use Mix.Project

  # add `release`
  def project do
    [
      app: :simple,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        simple: [
          steps: [:assemble, &Expkg.assemble/1],
          expkg: [
            executable_name: "simple-cli",
            no_args_command: "start",
            commands: [
              :start,
              :stop,
              :service,
              :remote,
              :eval,
              :rpc,
              [
                name: "migrate",
                help: "Run database migrations",
                eval: "Simple.Release.migrate()"
              ],
              [
                name: "create-admin",
                help: "Run database migrations",
                eval: {Simple, :create_admin, [:username, :password]}
              ],
              [
                name: "break-something",
                help: "Run database migrations",
                rpc: "Simple.break_something()"
              ]
            ],
            hide: [:eval, :rpc, :remote]
          ]
        ]
      ]
    ]
  end

  # add `mod: {MyModule, []}` to `application`
  def application do
    [
      extra_applications: [:logger],
      mod: {Simple, []}
    ]
  end

  defp deps do
    [
      {:expkg, path: "../../"},
      {:ecto, "~> 3.7"}
    ]
  end
end
