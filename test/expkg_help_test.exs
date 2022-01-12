defmodule Expkg.HelpTest do
  use ExUnit.Case
  alias Expkg.Help
  alias Expkg.Commands.{Command, CompoundCommand, EvalCommand, RpcCommand}
  doctest Expkg.Help

  describe "Help.generate/?" do
    test "generates help" do
      expkg = %Expkg{
        executable_name: "lies-cli",
        release: %Mix.Release{name: "lies"},
        commands: [
          %Command{
            name: "start",
            help: "Start lying to me"
          },
          %CompoundCommand{
            name: "some",
            help: "Do stuff",
            commands: [
              %EvalCommand{name: "thing", help: "Do something", expr: "Some.thing()"},
              %RpcCommand{
                name: "one",
                help: "Who is someone?",
                expr: {Some, :one, [:who]}
              }
            ]
          }
        ]
      }

      assert ~S"""
             \\Usage: lies-cli <command> [args]
             \\
             \\Commands:
             \\
             \\start           Start lying to me
             \\some <command>  Do stuff
             \\
             \\Type 'lies-cli help <command>' to get help for a specific command.
             """ == Help.generate(expkg).help["help"]

      assert ~S"""
             \\Usage: lies-cli some <command> [args]
             \\
             \\Commands:
             \\
             \\thing      Do something
             \\one <who>  Who is someone?
             """ == Help.generate(expkg).help["some"]
    end
  end
end
