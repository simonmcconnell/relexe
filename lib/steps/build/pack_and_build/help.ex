defmodule Expkg.Steps.Build.PackAndBuild.Help do
  @moduledoc "Generate help (in the form of multi-line `zig` strings) for the package."
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log

  alias Expkg.Steps.Build.PackAndBuild.Commands.{
    Command,
    CompoundCommand,
    EvalCommand,
    RpcCommand
  }

  @args "[args]"
  @command "<command>"
  @expr "<expr>"

  def generate(%Context{} = context, commands) do
    Log.info(:step, "Generating CLI help")

    options = context.mix_release.options[:expkg] || []
    executable_name = options[:executable_name] || Atom.to_string(context.mix_release.name)

    {commands_help, help} =
      commands
      |> drop_hidden_commands(options[:hide] || [])
      |> commands_help(executable_name)

    usage = """
    \\\\Usage: #{executable_name} #{if options[:no_args_command] == :start, do: "[command]", else: @command} #{@args}
    \\\\
    \\\\Commands:
    \\\\
    #{Enum.join(commands_help, "\n")}
    \\\\
    \\\\Type '#{executable_name} help <command>' to get help for a specific command.
    ;
    """

    Map.put(help, "help", usage)
  end

  def commands_help(commands, executable_name) do
    command_width = command_width(commands)

    Enum.map_reduce(commands, %{}, fn command, acc ->
      {usage_extra, command_extra} =
        case command do
          %{name: rpc_or_eval} when rpc_or_eval in ~w(rpc eval) -> {"", "\"expr\""}
          %CompoundCommand{} -> {"#{@command} #{@args}", @command}
          %Command{args: []} -> {"", ""}
          %Command{args: _args} -> {@args, @args}
          %RpcCommand{} -> {"", ""}
          %EvalCommand{} -> {"", ""}
          %{expr: {_, _, []}} -> {"", ""}
          %{expr: {_, _, args}} -> {@args, args |> Enum.map(&"<#{&1}>") |> Enum.join(" ")}
          _ -> {"", ""}
        end

      padded_command = String.pad_trailing("#{command.name} #{command_extra}", command_width)
      command_help_line = "\\\\#{padded_command}#{command.help}"

      {sub_commands_lines, _sub_command_help} =
        case command do
          %CompoundCommand{commands: cmds} ->
            commands_help(cmds, executable_name)

          _ ->
            {[], nil}
        end

      command_help =
        case command do
          %CompoundCommand{} ->
            """
            \\\\Usage: #{executable_name} #{command.name} #{usage_extra}
            \\\\
            \\\\Commands:
            \\\\
            #{Enum.join(sub_commands_lines, "\n")}
            ;
            """

          _ ->
            "\"#{command.help}\\nUsage: #{executable_name} #{command.name} #{usage_extra}\";"
        end

      {command_help_line, Map.put(acc, command.name, command_help)}
    end)
  end

  @spaces_after_command 2
  defp command_width(commands, min \\ 0)
  defp command_width([], min), do: min + @spaces_after_command

  defp command_width(commands, min) do
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
end
