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
          steps: [:assemble, &Relexe.assemble/1],
          relexe: [
            no_args_command: :start,
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
                help: "Create an admin user",
                eval: {Simple.Release, :create_admin, [:username, :password]}
              ],
              [
                name: "create-admin2",
                help: "Create an admin user",
                eval: {Simple.Release, :create_admin, [:username, :password]}
              ],
              [
                name: "break-something",
                help: "Break something!",
                rpc: "Simple.break_something()"
              ],
              [
                name: "create-admin-rpc",
                help: "Create an admin user",
                rpc: {Simple.Release, :create_admin, [:username, :password]}
              ]
            ],
            env: [windows: [RELEASE_DISTRIBUTION: "sname", RELEASE_NAME: "bananas_release"]],
            hide: [:eval, :rpc, :remote],
            targets: [windows: [os: :windows, cpu: :x86_64]]
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
      {:relexe, path: "../../"},
      {:ecto, "~> 3.7"}
    ]
  end
end
