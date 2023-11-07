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
              [name: :remote, hidden: true],
              [name: :eval, hidden: true],
              [name: :rpc, hidden: true],
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
                name: "create-admin-rpc",
                help: "Create an admin user",
                rpc: {Simple.Release, :create_admin, [:username, :password]}
              ],
              [
                name: "raise-exception",
                help: "Raise an exception",
                eval: "Simple.Release.raise_exception()"
              ],
              [
                name: "write-to-file",
                help: "Writes to C:/temp/test.txt",
                eval: "Simple.Release.write_to_file()"
              ],
            ],
            env: [windows: [RELEASE_DISTRIBUTION: "sname", RELEASE_NAME: "bananas_release"]],
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
