defmodule Relexe.Steps.Build.PackAndBuild.Commands do
  defmodule Command do
    @enforce_keys [:name, :help]
    defstruct [:name, :help, hidden: false, args: []]

    @type t :: %__MODULE__{
            name: String.t(),
            help: String.t(),
            args: [String.t()],
            hidden: boolean
          }
  end

  defmodule CompoundCommand do
    @enforce_keys [:name, :help]
    defstruct [:name, :help, hidden: false, args: [], commands: []]

    @type t :: %__MODULE__{
            name: String.t(),
            help: String.t(),
            commands: [Relexe.Commands.t()],
            hidden: boolean
          }
  end

  defmodule EvalCommand do
    @enforce_keys [:name, :help, :expr]
    defstruct [:name, :help, :expr, hidden: false]

    @type t :: %__MODULE__{
            name: String.t(),
            help: String.t(),
            expr: String.t() | Commands.mod_fn_args(),
            hidden: boolean
          }
  end

  defmodule RpcCommand do
    @enforce_keys [:name, :help, :expr]
    defstruct [:name, :help, :expr, hidden: false]

    @type t :: %__MODULE__{
            name: String.t(),
            help: String.t(),
            expr: String.t() | Commands.mod_fn_args(),
            hidden: boolean
          }
  end

  import Relexe.Utils

  alias __MODULE__.{Command, CompoundCommand, EvalCommand, RpcCommand}
  alias Burrito.Builder.Log

  @type t :: Command.t() | CompoundCommand.t() | EvalCommand.t() | RpcCommand.t()
  @type arg_type :: :string | :integer | :float

  @type command ::
          :start
          | :start_iex
          | :stop
          | :restart
          | :rpc
          | :eval
          | :remote
          | :pid
          | :version
          | :service
          | :daemon
          | custom_command

  @type custom_command :: {atom | String.t(), [custom_command_option]}
  @type custom_command_option ::
          {:help, String.t()}
          | {:eval, String.t() | mod_fn_args()}
          | {:rpc, String.t() | mod_fn_args()}
  @type mod_fn_args :: {module(), atom(), [{arg_name :: atom(), arg_type}]}

  @builtin_commands ~w(start start_iex service eval rpc remote restart stop pid version)

  @doc "Default commands"
  def default, do: @builtin_commands

  @doc "Parse the CLI commands defined for the release"
  @spec parse([command], release_name :: String.t(), os) :: [t()]
        when os: :windows | :darwin | :linux
  def parse(commands, release_name, os) when is_list(commands) do
    Log.info(:step, "Parsing CLI commands")

    commands
    |> preprocess()
    |> do_parse([], release_name, os)
  end

  defp preprocess(commands) do
    Enum.map(commands, fn
      cmd when is_list(cmd) -> Keyword.update!(cmd, :name, &ensure_string/1)
      name when is_binary(name) or is_atom(name) -> ensure_string(name)
    end)
  end

  defp do_parse([], parsed, _release_name, _os) do
    parsed
    |> List.flatten()
    |> Enum.reverse()
  end

  defp do_parse([command | commands], parsed, release_name, os) do
    parsed_command = parse_command(command, release_name, os)
    do_parse(commands, [parsed_command | parsed], release_name, os)
  end

  defp parse_command(name, release_name, os) when is_binary(name) and name in @builtin_commands do
    parse_command([name: name], release_name, os)
  end

  defp parse_command(command, release_name, os) when is_list(command) do
    name = Keyword.fetch!(command, :name)

    if name in @builtin_commands do
      parse_builtin_command(name, command, release_name, os)
    else
      parse_custom_command(name, command, release_name, os)
    end
  end

  defp parse_builtin_command("service", command, release_name, :windows) do
    %CompoundCommand{
      name: "service",
      help: "Add, remove, start or stop the #{release_name} Windows Service",
      hidden: Keyword.get(command, :hidden, false),
      commands: [
        %Command{name: "add", help: "Add Windows Service"},
        %Command{name: "remove", help: "Remove the service"},
        %Command{name: "start", help: "Start the service"},
        %Command{name: "stop", help: "Stop the service"},
        %Command{name: "list", help: "List installed services"},
        %Command{name: "help", help: "Show service controller help"}
      ]
    }
  end

  defp parse_builtin_command("daemon", _command, _release_name, _os) do
    raise("not implemented")
  end

  defp parse_builtin_command(name, command, release_name, _os) do
    hidden = Keyword.get(command, :hidden, false)

    help =
      case name do
        "start" -> "Start #{release_name}"
        "start_iex" -> "Start #{release_name} with IEx attached"
        "stop" -> "Stop #{release_name}"
        "restart" -> "Restart #{release_name}"
        "pid" -> "Prints the operating system PID of the running system"
        "version" -> "Print the application version"
        "eval" -> "Executes an expression on a new, non-booted system"
        "rpc" -> "Executes an expression remotely on the running system"
        "remote" -> "Connects to the running system via a remote shell"
      end

    data = [name: name, help: help, hidden: hidden]

    data =
      if name in ~w[eval rpc] do
        Keyword.put(data, :args, ["expr"])
      else
        data
      end

    struct!(Command, data)
  end

  defp parse_custom_command(name, command, release_name, os) when name not in @builtin_commands do
    help = Keyword.fetch!(command, :help)
    hidden = Keyword.get(command, :hidden, false)

    data = [name: name, help: help, hidden: hidden]

    cond do
      Keyword.has_key?(command, :rpc) ->
        validate_rpc_or_eval_command!(command[:rpc], :rpc)
        data = Keyword.put(data, :expr, command[:rpc])

        # TODO: commands with args
        struct!(RpcCommand, data)

      Keyword.has_key?(command, :eval) ->
        validate_rpc_or_eval_command!(command[:eval], :eval)
        data = Keyword.put(data, :expr, command[:eval])

        # TODO: commands with args
        struct!(EvalCommand, data)

      Keyword.has_key?(command, :commands) ->
        nested_compound_commands? =
          Enum.any?(command[:commands], &Keyword.has_key?(&1, :commands))

        if nested_compound_commands? do
          raise ArgumentError, message: "compound commands cannot be nested"
        end

        commands = Keyword.fetch!(command, :commands)
        parsed_commands = parse(commands, release_name, os)
        data = Keyword.put(data, :commands, parsed_commands)

        struct!(CompoundCommand, data)

      true ->
        raise ArgumentError, message: "custom commands must contain an :rpc or :eval option"
    end
  end

  defp validate_rpc_or_eval_command!(fn_string, _rpc_or_eval)
       when is_binary(fn_string) do
    :ok
  end

  defp validate_rpc_or_eval_command!({m, f, a}, rpc_or_eval)
       when is_atom(m) and is_atom(f) and is_list(a) do
    if Enum.all?(a, fn arg -> is_binary(arg) or is_atom(arg) end) do
      :ok
    else
      raise ArgumentError,
        message: "#{rpc_or_eval} argument names must be strings or atoms"
    end
  end

  defp validate_rpc_or_eval_command!(_, rpc_or_eval) do
    raise ArgumentError,
      message:
        "#{rpc_or_eval} commands must be a string or {Module, :function, [arg_names]} tuple"
  end
end
