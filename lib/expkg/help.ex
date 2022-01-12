defmodule Expkg.Help do
  alias Expkg.Commands.Command
  alias Expkg.Commands.CompoundCommand

  @args "[args]"
  @command "<command>"

  @doc "Generate help (in the form of multi-line `zig` strings) for the package."
  @spec generate(Expkg.t()) :: Expkg.t()
  def generate(%Expkg{} = expkg) do
    executable_name = expkg.executable_name || expkg.release.name
    command_width = command_width(expkg.commands)

    {commands_lines, help} =
      expkg
      |> remove_hidden_commands()
      |> commands_help(executable_name, command_width)

    usage = """
    \\\\Usage: #{executable_name} #{if expkg.no_args_command == :start, do: "[command]", else: @command} #{@args}
    \\\\
    \\\\Commands:
    \\\\
    #{Enum.join(commands_lines, "\n")}
    \\\\
    \\\\Type '#{executable_name} help <command>' to get help for a specific command.
    """

    %Expkg{expkg | help: Map.put(help, "help", usage)}
  end

  def commands_help(commands, executable_name, command_width) do
    Enum.map_reduce(commands, %{}, fn command, acc ->
      {usage_extra, command_extra} =
        case command do
          %CompoundCommand{} -> {"#{@command} #{@args}", @command}
          %Command{args: []} -> {"", ""}
          %Command{args: _args} -> {@args, @args}
          %{expr: {_, _, []}} -> {"", ""}
          %{expr: {_, _, args}} -> {@args, args |> Enum.map(&"<#{&1}>") |> Enum.join(" ")}
          _ -> {"", ""}
        end

      padded_command = String.pad_trailing("#{command.name} #{command_extra}", command_width)
      command_help_line = "\\\\#{padded_command}#{command.help}"

      {sub_commands_lines, _sub_command_help} =
        case command do
          %CompoundCommand{commands: cmds} ->
            commands_help(cmds, executable_name, command_width(cmds))

          _ ->
            {[], nil}
        end

      command_help = """
      \\\\Usage: #{executable_name} #{command.name} #{usage_extra}
      \\\\
      \\\\Commands:
      \\\\
      #{Enum.join(sub_commands_lines, "\n")}
      """

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

  defp remove_hidden_commands(%{hide: [], commands: commands}), do: commands

  defp remove_hidden_commands(%{hide: hidden_commands, commands: commands}) do
    Enum.reject(commands, fn command -> command.name in hidden_commands end)
  end
end
