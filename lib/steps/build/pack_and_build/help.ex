defmodule Expkg.Steps.Build.PackAndBuild.Help do
  @moduledoc "Generate help (in the form of multi-line `zig` strings) for the package."
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log

  alias Expkg.Steps.Build.PackAndBuild.Commands.{
    Command,
    CompoundCommand
  }

  # @args "[ARGS]"
  @command "<COMMAND>"

  @spec generate(Context.t(), [Command.t()]) :: map
  def generate(%Context{} = context, commands) do
    Log.info(:step, "Generating CLI help")

    options = context.mix_release.options[:expkg] || []
    executable_name = options[:executable_name] || Atom.to_string(context.mix_release.name)
    no_args_command = Atom.to_string(options[:no_args_command] || :help)

    {commands_help, help} =
      commands
      |> drop_hidden_commands(options[:hide] || [])
      |> commands_help(executable_name, no_args_command)

    usage = """
    \\\\USAGE:
    \\\\  #{executable_name} #{if options[:no_args_command] == :start, do: "[COMMAND]", else: @command}
    \\\\
    \\\\COMMANDS:
    #{Enum.join(commands_help, "\n")}
    \\\\
    \\\\HELP:
    \\\\  help <COMMAND>  Print help for a specific command.
    ;
    """

    Map.put(help, "help", usage)
  end

  def commands_help(commands, executable_name, no_args_command)
      when is_list(commands) and is_binary(executable_name) and is_binary(no_args_command) do
    command_width = command_width(commands)

    Enum.map_reduce(commands, %{}, fn command, acc ->
      extra =
        case command do
          %{name: rpc_or_eval} when rpc_or_eval in ~w(rpc eval) ->
            "<EXPR>"

          %CompoundCommand{commands: _sub_commands} ->
            @command

          %Command{args: args} when args != [] ->
            args |> Enum.map(&"<#{String.upcase(to_string(&1))}>") |> Enum.join(" ")

          %{expr: {_, _, args}} when args != [] ->
            args |> Enum.map(&"<#{String.upcase(to_string(&1))}>") |> Enum.join(" ")

          _ ->
            ""
        end

      padded_command = String.pad_trailing("#{command.name} #{extra}", command_width)

      command_help_line =
        ~S"\\  " <>
          padded_command <>
          command.help <>
          if command.name == no_args_command, do: " (default)", else: ""

      {sub_commands_lines, _sub_command_help} =
        case command do
          %CompoundCommand{commands: cmds} ->
            commands_help(cmds, executable_name, no_args_command)

          _ ->
            {[], nil}
        end

      command_help =
        case command do
          %CompoundCommand{} ->
            """
            \\\\#{command.help}
            \\\\
            \\\\USAGE:
            \\\\  #{executable_name} #{command.name} #{extra}
            \\\\
            \\\\COMMANDS:
            #{Enum.join(sub_commands_lines, "\n")}
            ;
            """

          _ ->
            """
            \\\\#{command.help}
            \\\\
            \\\\USAGE:
            \\\\  #{executable_name} #{command.name} #{extra}
            ;
            """
        end

      {command_help_line, Map.put(acc, command.name, command_help)}
    end)
  end

  @spaces_after_command 2
  defp command_width(commands, min \\ 0) do
    Enum.reduce(commands, min, fn
      %Command{args: args, name: name}, acc when args != [] ->
        args_len = String.length(Enum.join(args, " "))
        max(acc, String.length(name) + args_len + 1)

      %CompoundCommand{name: name}, acc ->
        max(acc, String.length(name) + String.length(@command) + 1)

      %{name: name, expr: {_, _, args}}, acc when args != [] ->
        args_len =
          Enum.reduce(args, 0, fn arg, acc ->
            acc + String.length(to_string(arg)) + 3
          end)

        max(acc, String.length(name) + args_len)

      %{name: name}, acc ->
        max(acc, String.length(name))
    end) + @spaces_after_command
  end

  defp drop_hidden_commands(commands, []), do: commands

  defp drop_hidden_commands(commands, hidden_commands) do
    Enum.reject(commands, fn command -> command.name in hidden_commands end)
  end

  # defp command_has_args?(%Command{args: args}) when args != [], do: true
  # defp command_has_args?(%RpcCommand{expr: {_, _, args}}) when args != [], do: true
  # defp command_has_args?(%EvalCommand{expr: {_, _, args}}) when args != [], do: true
  # defp command_has_args?(_command), do: false
end
