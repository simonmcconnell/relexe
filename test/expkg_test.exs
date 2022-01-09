defmodule ExpkgTest do
  use ExUnit.Case
  alias Expkg.Commands
  alias Expkg.Commands.{Command, CompoundCommand, EvalCommand, RpcCommand}
  # doctest Expkg

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
                     expr: {Some, :one, [who: :string]}
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
                       [name: "one", help: "Who is someone?", rpc: {Some, :one, [who: :string]}]
                     ]
                   ]
                 ],
                 "Possum Detector",
                 :windows
               )
    end
  end
end
