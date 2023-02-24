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
            default_command: :start,
            commands: [
              :start,
              :stop,
              :service,
              {:remote, hidden: true},
              {:eval, hidden: true},
              {:rpc, hidden: true},
              {
                "migrate",
                help: "Run database migrations", eval: "Simple.Release.migrate()"
              },
              {
                "create-admin",
                help: "Create an admin user",
                eval: {Simple.Release, :create_admin, [:username, :password]}
              },
              {
                "create-admin2",
                help: "Create an admin user",
                eval: {Simple.Release, :create_admin, ~w[username password]}
              },
              {
                "create-admin-rpc",
                help: "Create an admin user",
                rpc: {Simple.Release, :create_admin, [:username, :password]}
              },
              {
                "break-something",
                help: "Break something!", rpc: "Simple.break_something()"
              }
            ],
            env: [windows: [RELEASE_DISTRIBUTION: "none", RELEASE_NAME: "bananas_release", PANTS: "navy corduroy slacks"]],
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
      {:relexe, path: "../../"}
    ]
  end
end
