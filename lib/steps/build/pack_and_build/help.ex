defmodule Relexe.Steps.Build.PackAndBuild.Help do
  @moduledoc "Generate help (in the form of multi-line `zig` strings) for the package."
  import Relexe.Utils

  alias Burrito.Builder.Context
  alias Burrito.Builder.Log

  alias Relexe.Steps.Build.PackAndBuild.Commands.{
    Command,
    CompoundCommand
  }

  @command "<COMMAND>"

  @spec generate(Context.t(), [Command.t()]) :: map
  def generate(%Context{} = context, commands) do
    Log.info(:step, "Generating CLI help")

    options = context.mix_release.options[:relexe] || []
    executable_name = Atom.to_string(context.mix_release.name)

    executable =
      if context.target.os == :windows do
        "#{executable_name}.exe"
      else
        executable_name
      end

    default_command =
      Keyword.get(options, :default_command, :help)
      |> ensure_string()

    {commands_help, help} =
      commands
      |> Enum.reject(fn command -> command.hidden end)
      |> commands_help(executable, default_command)

    # TODO: put .exe after the executable name for windows builds
    usage = """
    \\\\USAGE:
    \\\\  #{executable} [COMMAND]
    \\\\
    \\\\COMMANDS:
    #{Enum.join(commands_help, "\n")}
    \\\\
    \\\\HELP:
    \\\\  help <COMMAND>
    \\\\
    ;
    """

    Map.put(help, "help", usage)
  end

  @doc "Generate help for the release executable."
  def commands_help(commands, executable, default_command)
      when is_list(commands) and is_binary(executable) and is_binary(default_command) do
    command_width = command_width(commands)

    Enum.map_reduce(commands, %{}, fn command, acc ->
      extra =
        case command do
          %CompoundCommand{commands: _sub_commands} ->
            @command

          _ ->
            ""
        end

      padded_command = String.pad_trailing("#{command.name} #{extra}", command_width)

      command_help_line =
        ~S"\\  " <>
          padded_command <>
          command.help <>
          if command.name == default_command, do: " (default)", else: ""

      {sub_commands_lines, _sub_command_help} =
        case command do
          %CompoundCommand{commands: cmds} ->
            commands_help(cmds, executable, default_command)

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
            \\\\  #{executable} #{command.name} #{extra}
            \\\\
            \\\\COMMANDS:
            #{Enum.join(sub_commands_lines, "\n")}
            \\\\
            ;
            """

          _ ->
            """
            \\\\#{command.help}
            \\\\
            \\\\USAGE:
            \\\\  #{executable} #{command.name} #{extra}
            \\\\
            ;
            """
        end

      {command_help_line, Map.put(acc, command.name, command_help)}
    end)
  end

  @spaces_after_command 2
  defp command_width(commands, min \\ 0) do
    widest_width =
      Enum.reduce(commands, min, fn
        %CompoundCommand{name: name}, acc ->
          max(acc, String.length(name) + String.length(@command) + 1)

        %{name: name}, acc ->
          max(acc, String.length(name))
      end)

    widest_width + @spaces_after_command
  end
end
