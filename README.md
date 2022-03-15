# relexe

[hex](https://hex.pm/packages/relexe) - [docs](https://hexdocs.pm/relexe)

## About
<!-- MDOC !-->

Generate an Elixir [release](https://hexdocs.pm/mix/Mix.Tasks.Release.html) with a **binary executable** launcher, instead of batch/shell scripts.

`Relexe` uses [Burrito](https://github.com/burrito-elixir/burrito) with a modified build phase.  Relexe's build phase uses Zig to build an executable launcher with a user-specified CLI.

## Usage

Create a release in `mix.exs` like so:

```elixir
def project do
  [
    ...
    releases: [
      bananas: [
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
              eval: "Bananas.Release.migrate()"
            ],
            [
              name: "create-admin",
              help: "Create an admin user",
              eval: {Bananas.Release, :create_admin, [:username, :password]}
            ],
            [
              name: "something",
              help: "Do something",
              rpc: "Bananas.Release.something()"
            ]
          ],
          hide: [:remote, :eval, :rpc],
          targets: [windows: [os: :windows, cpu: :x86_64]]
        ]
      ]
    ]
  ]
end
```

Run `mix release` and you'll have `bananas.exe` in the `bin` folder of your release.  The `help` for this example would be:

```
USAGE:
  bananas [COMMAND]

COMMANDS:
  start              Start bananas (default)
  stop               Stop bananas
  service <COMMAND>  Add, remove, start or stop the bananas Windows Service
  migrate            Run database migrations
  create-admin       Create an admin user
  something          Do something

HELP:
  help <COMMAND>
```

Running `bananas create-admin` would prompt the user for the `username` and `password` ...

```
bananas create-admin
username: Eric
password: BananaMan
```

... before calling the `{Bananas.Release, :create_admin, ["Eric", "BananaMan"]}` `MFA` via `eval`.

## Options

- `executable_name`: name of the executable.  Defaults to the name of the release.
- `no_args_command`: the command to run if no args are passed.  Defaults to `help`.
- `commands`: list of commands to include in the release.  See **Commands** below for details.
- `hide`: list of commands to omit from the help.
- `targets`: list of targets, as defined by Burrito.
- `allow_eval`: include the `eval` command <!-- TODO: isn't this pointless if we define the commands? -->
- `allow_rpc`: include the `rpc` command

## Commands

One of the main goals of this project is to create a release executable with custom commands.  For example, you might want to create a `migrate` command to run database migrations.

### Built-in Commands

The default commands are the same commands included with a regular `Mix` release, excpet that `install`, which installs a Windows service is replaced by `service add`.  The default commands are `start start_iex service eval rpc remote restart stop pid version`.

#### Windows Service

The Windows Service controls are managed through the release executable.  In a `Mix` release, you use `bananas.bat install` to create the service and then manage the service using `erlsrv.exe`.  With `Relexe`, you manage the service with `bananas.exe service add`, `bananas.exe service start` etc.

### `eval` and `rpc` Commands

`eval` and `rpc` commands are defined as a three-element keyword list.  The command can be defined as either a straight function call, e.g. `Bananas.Release.migrate()`, or as a `{Module, :function, [arg_names]}` tuple, e.g. `{Bananas.Release, :create_admin, [:username, :password]}`.  An MFA command will prompt the user for each argument value (it is not feasible to handle args on the command line in Windows).

```elixir
# Function call
[
  name: "migrate",
  help: "Run database migrations",
  eval: "Bananas.Release.migrate()"
],

# MFA style
[
  name: "create-admin",
  help: "Create an admin user",
  eval: {Bananas.Release, :create_admin, [:username, :password]}
]
```

## Environment Variables

TODO

## Disabling EMPD

TODO

<!-- MDOC !-->

## What is the difference?

- if you want a single binary, use `burrito` or `bakeware`
- if you want to add CLI commands to a Mix Release, consider using `relexe`
- if end users are installing your software, consider using `relexe`
- if you're deploying to your own infrastructure, use whatever you like

|                         | Mix.Release                                       | Burrito           | Relexe                      |
| ----------------------- | ------------------------------------------------- | ----------------- | --------------------------- |
| single file?            | ❌                                                 | ✅                 | ❌                           |
| plugins                 | ❌                                                 | ✅                 | ✅ (Burrito's) |
| launcher                | batch/shell scripts                               | binary executable | binary executable           |
| windows service control | `<release>.bat install` then through `erlsrv.exe` | DIY, e.g. NSSM    | `<release>.exe service` CLI                         |
| run laucher w/o args    | `help`                                            | `start`           | `start` or `help`           |

## Credits

- [bakeware](https://github.com/bake-bake-bake/bakeware)
- [burrito](https://github.com/burrito-elixir/burrito)
- [elixir](https://elixir-lang.org)
- [zig](https://ziglang.org/)
- [zigler](https://github.com/ityonemo/zigler)
