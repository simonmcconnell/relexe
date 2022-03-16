# relexe

[hex](https://hex.pm/packages/relexe) - [docs](https://hexdocs.pm/relexe)

## About
<!-- MDOC !-->

Generate an Elixir [release](https://hexdocs.pm/mix/Mix.Tasks.Release.html) with a **binary executable** launcher, instead of batch/shell scripts.

`Relexe` uses [Burrito](https://github.com/burrito-elixir/burrito) with a modified build phase thate uses Zig to build an executable launcher with a user-specified CLI.

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
          env: [
            windows: [
              RELEASE_DISTRIBUTION: "none",
              RELEASE_NODE: "bananas69"
            ]
          ]
          hide: [:remote, :eval, :rpc],
          targets: [windows: [os: :windows, cpu: :x86_64]]
        ]
      ]
    ]
  ]
end
```

Run `mix release` and you'll have `bananas.exe` in the `bin` folder of your release.  The environment variables specified in `env` are written to `releases/<version>/.env`, which is checked when starting your app.  See [Environment Variables](#environment-variables) for more details.

The `help` for this example would be:

```
USAGE:
  bananas.exe [COMMAND]

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
> bananas.exe create-admin
username: Eric
password: BananaMan
```

... before calling the `{Bananas.Release, :create_admin, ["Eric", "BananaMan"]}` `MFA` via `eval`.

## Options

- `no_args_command`: the command to run if no args are passed.  Defaults to `help`.
- `commands`: optional list of commands to include in the release.  See [Commands](#commands) for details.
- `hide`: optional list of commands to omit from the help.
- `env`: optional list of environment variables for each target.
- `targets`: list of targets, as defined by Burrito.

## Commands

One of the main goals of this project is to create a release executable with custom commands.  For example, you might want to create a `migrate` command to run database migrations.

### Built-in Commands

The default commands are the same commands included with a regular `Mix` release, excpet that `install`, which installs a Windows service is replaced by `service add`.  The default commands are `start start_iex service eval rpc remote restart stop pid version` on Windows and `start start_iex daemon daemon_iex eval rpc remote restart stop pid version` on Unixesque OSes.

#### Windows Service

The Windows Service controls are managed through the release executable.  In a `Mix` release, you use `bananas.bat install` to create the service and then manage the service using `erlsrv.exe`.  With `Relexe`, you manage the service with `bananas.exe service add`, `bananas.exe service start` etc.

### `eval` and `rpc` Commands

`eval` and `rpc` commands are defined as a three-element keyword list with a `name`, `help` string and `eval` or `rpc` command.  The command can be either a straight function call, e.g. `Bananas.Release.migrate()`, or a `{Module, :function, [arg_names]}` tuple, e.g. `{Bananas.Release, :create_admin, [:username, :password]}`.  An MFA command will prompt the user for each argument value, as it is not feasible to handle args on the command line in Windows.

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
  rpc: {Bananas.Release, :create_admin, [:username, :password]}
]
```

## Environment Variables

The environment variables that you define are written to `<app>/releases/<version>/.env` and/or `<app>/releases/<version>/.env.<command>`.  They are defined per `target` and can be configured either by setting the `relexe[:env]` option in your release config or by creating a `/rel/relexe/.env.<target>[.command].eex` file.  If both exist, the options take precendence.

### `env` Option

Specify the environment variables for each target in a keyword list in the `env` option.  If you want to load a different set of environment variables for certain commands, specify those with the command as the key under the target.  If you specify a command specific file, **only that file will be parsed**, i.e. the `.env` will be ignored.

For example, the contrived example below will output two files: `bananas/releases/1.0.0/.env` and `bananas/releases/1.0.0/.env.sales`.  If you call `bananas.exe start` it will load the environment variables from `.env`.  If you call `bananas.exe sales` it will load the environment variables from `.env.sales`.

```elixir
releases: [
  bananas: [
    steps: [:assemble, &Relexe.assemble/1],
    relexe: [
      commands: [:start, :stop, :sales],
      env: [
        windows: [
          RELEASE_DISTRIBUTION: "none",
          RELEASE_NODE: "bananas69",
          sales: [
            RELEASE_DISTRIBUTION: "name",
            RELEASE_NODE: "banana_sales"
          ]
        ]
      ],
      targets: [
        windows: [os: :windows, cpu: :x86_64]
      ]
    ]
  ]
]
```

```
# .env
RELEASE_DISTRIBUTION=none
RELEASE_NODE=bananas69
```

```
# .env.sales
RELEASE_DISTRIBUTION=name
RELEASE_NODE=banana_sales
```

### EEx Template

Environment variables can also be specified by way of an `EEx` template.  Template files shall be created in `/rel/relexe` and be named `.env.<target>.eex` or `.env.<target>.<command>.eex`, where `<target>` is `windows`, `linux` or `darwin` (TODO: or is it `macos`?) and `<command>` is the name of the command that these environment variables are for.

For example, to recreate the Mix Release `daemon` environment variables, we create a `/rel/relexe/.env.linux.daemon.eex`.

```
HEART_COMMAND="<%= @context.mix_release.path %>/bin/<%= @context.mix_release.name %> daemon"
ELIXIR_ERL_OPTIONS="-heart"
```

**TODO: I'm not sure if this actually works, as I don't deploy to linux/macos.  Please let me know if it doesn't :)**

## Disabling EMPD

TODO

- with env vars
- with empdless/empdlessless/etc

<!-- MDOC !-->

## What is the difference?

- if you want a single binary, use `burrito` or `bakeware`
- if you want to add CLI commands to a Mix Release, consider using `relexe`
- if end users are installing your software, consider using `relexe`
- if you're deploying to your own infrastructure, use whatever you like

|                         | Mix.Release                                       | Burrito                       | Relexe                      |
| ----------------------- | ------------------------------------------------- | ----------------------------- | --------------------------- |
| single file?            | ❌                                                 | ✅                             | ❌                           |
| plugins                 | ❌                                                 | ✅                             | ✅ (Burrito's)               |
| launcher                | batch/shell scripts                               | binary executable             | binary executable           |
| windows service control | `<release>.bat install` then through `erlsrv.exe` | non-goal, i.e. DIY, e.g. NSSM | `<release>.exe service` CLI |
| run laucher w/o args    | `help`                                            | `start`                       | `start` or `help`           |

## TODO

- [ ] CI
- [ ] tests for `EnvVars`
- [ ] rename erl.exe and change icon
- [ ] test on macos & linux

## Notes

- This is at the 'barely works for my use case' stage of development.
- I've only tested this on Windows.
- I have no idea what I'm doing when it comes to writing Zig code.

## Credits

- [bakeware](https://github.com/bake-bake-bake/bakeware)
- [burrito](https://github.com/burrito-elixir/burrito)
- [elixir](https://elixir-lang.org)
- [zig](https://ziglang.org/)
- [zigler](https://github.com/ityonemo/zigler)
