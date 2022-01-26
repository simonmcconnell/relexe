# relexe

[hex](https://hex.pm/packages/relexe) - [docs](https://hexdocs.pm/relexe)

## What's all this about then?

 Thought it would be easier to create a binary executable using Zig in a Mix Release step than to figure out how to handle all the different ways to pass around and escape arguments in batch scripts, command prompt, powershell and powershell core.  I wanted to make it simple for the end user of software that is installed by them on their own, typically Windows, infrastructure.  

## What is the difference?

- if you want a single binary, use `burrito`
- if you want to add CLI commands to a Mix Release, consider using `relexe`
- if end users are installing your software, consider using `relexe`
- if you're deploying to your own infrastructure, use whatever you like

|                         | Mix.Release                                       | Burrito           | Relexe                      |
| ----------------------- | ------------------------------------------------- | ----------------- | --------------------------- |
| single file?            | ❌                                                 | ✅                 | ❌                           |
| plugins                 | ❌                                                 | ✅                 | ✅ - Burrito's plugin system |
| launcher                | batch/shell scripts                               | binary executable | binary executable           |
| windows service control | `<release>.bat install` then through `erlsrv.exe` | 🤷                 | release executable CLI      |
| run laucher w/o args    | `help`                                            | `start`?          | `start` or `help`           |

## About
<!-- MDOC !-->

Generate an Elixir [release](https://hexdocs.pm/mix/Mix.Tasks.Release.html) with a **binary executable** launcher, instead of batch/shell scripts.

`Relexe` uses [Burrito](https://github.com/burrito-elixir/burrito) with a modified build phase.  Relexe's build phase uses Zig to build an executable launcher with your specified CLI.

<!-- MDOC !-->

## Credits

- [elixir](https://elixir-lang.org)
- [zig](https://ziglang.org/)
- [zigler](https://github.com/ityonemo/zigler)
- [burrito](https://github.com/burrito-elixir/burrito)
- [bakeware](https://github.com/bake-bake-bake/bakeware)
