defmodule Relexe.HelpTest do
  use ExUnit.Case

  alias Burrito.Builder.Context
  alias Burrito.Builder.Target
  alias Relexe.Steps.Build.PackAndBuild.Help

  alias Relexe.Steps.Build.PackAndBuild.Commands.{
    Command,
    CompoundCommand,
    EvalCommand,
    RpcCommand
  }

  defp target do
    %Target{
      alias: :windows,
      cpu: :x86_64,
      cross_build: true,
      debug?: false,
      erts_source:
        {:local_unpacked,
         [
           path: "C:\\Users\\simon\\AppData\\Local\\Temp/unpacked_erts_8BF3630877228ABC"
         ]},
      os: :windows,
      qualifiers: [libc: nil]
    }
  end

  doctest Relexe.Steps.Build.PackAndBuild.Help

  describe "Help.generate/2" do
    test "generates help" do
      context = %Context{
        target: target(),
        work_dir: "",
        self_dir: "",
        halted: false,
        mix_release: %Mix.Release{
          name: :lies,
          options: [relexe: []]
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
             \\
             \\USAGE:
             \\  lies.exe [COMMAND]
             \\
             \\COMMANDS:
             \\  talk-to-me      Start lying to me
             \\  some <COMMAND>  Do stuff
             \\
             \\HELP:
             \\  help <COMMAND>
             \\
             ;
             """ == help["help"]

      assert ~S"""
             \\
             \\Do stuff
             \\
             \\USAGE:
             \\  lies.exe some <COMMAND>
             \\
             \\COMMANDS:
             \\  create-admin  Create administrator
             \\  thing         Do something
             \\  who           Who is someone?
             \\
             ;
             """ == help["some"]
    end

    test "generates help when no_args_command = :start" do
      context = %Context{
        target: target(),
        work_dir: "",
        self_dir: "",
        halted: false,
        mix_release: %Mix.Release{
          name: :lies,
          options: [relexe: [no_args_command: :start]]
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
             \\
             \\USAGE:
             \\  lies.exe [COMMAND]
             \\
             \\COMMANDS:
             \\  start  Start lies (default)
             \\  stop   Stop lies
             \\
             \\HELP:
             \\  help <COMMAND>
             \\
             ;
             """ == help["help"]
    end
  end
end
