defmodule Expkg.Help do
  @args "<args...>"
  @command "<command>"

  # @spec generate(Expkg.t()) :: Expkg.t()
  def generate(%Expkg{} = expkg) do
    executable_name = expkg.executable_name || expkg.release.name

    header = ~s"""
    \\\\Usage: #{executable_name}
    \\\\       #{executable_name} <command> [args...]
    \\\\
    \\\\Commands:
    \\\\
    """

    empty_line = "\\\\"

    command_width = command_width(expkg.commands)

    {commands_lines, help} =
      expkg |> remove_hidden_commands() |> commands_help(executable_name, command_width)

    usage =
      Enum.join(
        [
          header <> Enum.join(commands_lines, "\n"),
          empty_line,
          "\\\\Help:",
          empty_line,
          "\\\\  #{String.pad_trailing("help", command_width)}Print this help",
          "\\\\  #{String.pad_trailing("help <command>", command_width)}Print help for <command>"
        ],
        "\n"
      ) <> "\n;"

    %Expkg{expkg | help: Map.put(help, "help", usage)}
  end

  defp command_width([]), do: String.length("help <command>") + 4
  defp command_width(commands) do
    Enum.reduce(commands, String.length("help <command>"), fn command, acc ->
      # args_len = Enum.reduce(command.args, 0, fn arg, acc -> acc + 3 + String.length(arg) end)
      args_len = if command.args == [], do: 0, else: String.length(Enum.join(command.args, " ")) + 1
      command_len = if command.commands == [], do: 0, else: String.length(@command) + 1
      max(acc, String.length(command.name) + args_len + command_len)
    end) + 2
  end

  def commands_help(commands, executable_name, command_width) do
    Enum.map_reduce(commands, %{}, fn command, acc ->
      extra =
        cond do
          command.commands == [] and command.args == [] -> ""
          command.args == [] -> @command
          true -> Enum.join(command.args, " ")
        end

      padded_command = String.pad_trailing("#{command.name} #{extra}", command_width)
      command_help_line = "\\\\  #{padded_command}#{command.help}"
      {sub_commands_lines, _sub_command_help} =
        commands_help(command.commands, executable_name, command_width(command.commands)) |> IO.inspect(label: command.name)

      command_help = ~s"""
      \\\\Usage: #{executable_name} #{command.name} #{extra}
      \\\\
      \\\\Commands:
      \\\\
      #{Enum.join(sub_commands_lines, "\n")}
      """

      # command_help = Enum.join([header, Enum.join(sub_commands_lines, "\n")])

      {command_help_line, Map.put(acc, command.name, command_help)}
    end)
  end

  defp remove_hidden_commands(%{hidden_commands: [], commands: commands}), do: commands

  defp remove_hidden_commands(%{hidden_commands: hidden_commands, commands: commands}) do
    Enum.reject(commands, fn command -> command.name in hidden_commands end)
  end
end
