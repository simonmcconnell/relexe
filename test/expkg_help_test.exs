defmodule Expkg.HelpTest do
  use ExUnit.Case

  alias Burrito.Builder.Context
  alias Expkg.Steps.Build.PackAndBuild.Help

  alias Expkg.Steps.Build.PackAndBuild.Commands.{
    Command,
    CompoundCommand,
    EvalCommand,
    RpcCommand
  }

  doctest Expkg.Steps.Build.PackAndBuild.Help

  describe "Help.generate/2" do
    test "generates help" do
      context = %Context{
        target: :windows,
        work_dir: "",
        self_dir: "",
        halted: false,
        mix_release: %Mix.Release{
          name: "lies",
          options: [expkg: [executable_name: "lies-cli"]]
        }
      }

      commands = [
        %Command{
          name: "talk-to-me",
          help: "Start lying to me"
        },
        %CompoundCommand{
          name: "some",
          help: "Do stuff",
          commands: [
            %EvalCommand{
              name: "create-admin",
              help: "Create administrator",
              expr: {Accounts, :create_admin, [:username, :password]}
            },
            %EvalCommand{name: "thing", help: "Do something", expr: "Some.thing()"},
            %RpcCommand{
              name: "who",
              help: "Who is someone?",
              expr: {Some, :who, [:someone]}
            }
          ]
        }
      ]

      help = Help.generate(context, commands)

      assert ~S"""
             \\USAGE:
             \\  lies-cli <COMMAND>
             \\
             \\COMMANDS:
             \\  talk-to-me      Start lying to me
             \\  some <COMMAND>  Do stuff
             \\
             \\HELP:
             \\  help <COMMAND>  Print help for a specific command.
             ;
             """ == help["help"]

      assert ~S"""
             \\Do stuff
             \\
             \\USAGE:
             \\  lies-cli some <COMMAND>
             \\
             \\COMMANDS:
             \\  create-admin <USERNAME> <PASSWORD>  Create administrator
             \\  thing                               Do something
             \\  who <SOMEONE>                       Who is someone?
             ;
             """ == help["some"]
    end

    test "generates help when no_args_command = :start" do
      context = %Context{
        target: :windows,
        work_dir: "",
        self_dir: "",
        halted: false,
        mix_release: %Mix.Release{
          name: "lies",
          options: [expkg: [executable_name: "lies-cli", no_args_command: :start]]
        }
      }

      commands = [
        %Command{
          name: "start",
          help: "Start lies"
        },
        %Command{
          name: "stop",
          help: "Stop lies"
        }
      ]

      help = Help.generate(context, commands)

      assert ~S"""
             \\USAGE:
             \\  lies-cli [COMMAND]
             \\
             \\COMMANDS:
             \\  start  Start lies (default)
             \\  stop   Stop lies
             \\
             \\HELP:
             \\  help <COMMAND>  Print help for a specific command.
             ;
             """ == help["help"]
    end
  end
end
