defmodule Expkg.CommandsTest do
  use ExUnit.Case
  alias Expkg.Commands
  alias Expkg.Commands.{Command, CompoundCommand, EvalCommand, RpcCommand}
  doctest Expkg.Commands

  describe "Commands.parse/3" do
    test "builtin commands" do
      assert [
               %Command{
                 name: "start",
                 help: "Start Possum Detector"
               }
             ] == Commands.parse([:start], "Possum Detector", :windows)
    end

    test "compound commands" do
      assert [
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
             ] ==
               Commands.parse(
                 [
                   [
                     name: "some",
                     help: "Do stuff",
                     commands: [
                       [name: "thing", help: "Do something", eval: "Some.thing()"],
                       [name: "one", help: "Who is someone?", rpc: {Some, :one, [:who]}]
                     ]
                   ]
                 ],
                 "Possum Detector",
                 :windows
               )
    end

    test "compound commands must be rpc or eval" do
      assert_raise ArgumentError, "custom commands must contain an :rpc or :eval option", fn ->
        Commands.parse(
          [
            [
              name: "some",
              help: "Do stuff",
              commands: [
                [name: "thing", help: "Do something", args: [:username, :password]]
              ]
            ]
          ],
          "Possum Detector",
          :windows
        )
      end
    end

    test "cannot nest compound commands" do
      assert_raise ArgumentError, "compound commands cannot be nested", fn ->
        Commands.parse(
          [
            [
              name: "some",
              help: "Do stuff",
              commands: [
                [
                  name: "nested",
                  help: "nested command",
                  commands: [
                    [name: "thing", help: "Do something", eval: "Some.thing()"],
                    [name: "one", help: "Who is someone?", rpc: {Some, :one, [:who]}]
                  ]
                ]
              ]
            ]
          ],
          "Possum Detector",
          :windows
        )
      end
    end
  end
end
