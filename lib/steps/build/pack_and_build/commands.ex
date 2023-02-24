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
  @type mod_fn_args :: {module(), atom(), [arg_name]}
  @type arg_name :: atom | String.t()

  @builtin_commands ~w(start start_iex service eval rpc remote restart stop pid version)

  @doc "Default commands"
  def default, do: @builtin_commands

  @doc "Parse the CLI commands defined for the release"
  @spec parse([command], release_name :: String.t(), os) :: [t()]
        when os: :windows | :darwin | :linux
  def parse(commands, release_name, os) when is_list(commands) do
    Log.info(:step, "Parsing CLI commands")

    commands
    |> Enum.map(&preprocess/1)
    |> Enum.map(&parse_command(&1, release_name, os))
    |> Enum.reverse()
  end

  defp preprocess(name) when is_binary(name),
    do: {name, []}

  defp preprocess(name) when is_atom(name),
    do: {Atom.to_string(name), []}

  defp preprocess({name, opts}) when is_list(opts),
    do: {ensure_string(name), opts}

  defp preprocess({name, _opts}),
    do: raise("command options must be a list - command: #{name}")

  defp preprocess(command),
    do: raise("invalid command: #{command}")

  defp parse_command({"service", opts}, release_name, :windows) do
    %CompoundCommand{
      name: "service",
      help: "Add, remove, start or stop the #{release_name} Windows Service",
      hidden: Keyword.get(opts, :hidden, false),
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

  # TODO: implement daemon for unix systems
  defp parse_command("daemon", _command, _release_name, _os) do
    raise("not implemented")
  end

  defp parse_command({name, opts}, release_name, _os) when name in @builtin_commands do
    hidden = Keyword.get(opts, :hidden, false)

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

    command =
      if name in ~w[eval rpc] do
        [name: name, help: help, hidden: hidden, args: ["expr"]]
      else
        [name: name, help: help, hidden: hidden]
      end

    struct!(Command, command)
  end

  defp parse_command({name, opts}, release_name, os) when name not in @builtin_commands do
    help = Keyword.fetch!(opts, :help)
    hidden = Keyword.get(opts, :hidden, false)

    command = [name: name, help: help, hidden: hidden]

    cond do
      Keyword.has_key?(opts, :rpc) ->
        validate_rpc_or_eval_command!(opts[:rpc], :rpc)
        command = Keyword.put(command, :expr, opts[:rpc])

        # TODO: commands with args
        struct!(RpcCommand, command)

      Keyword.has_key?(opts, :eval) ->
        validate_rpc_or_eval_command!(opts[:eval], :eval)
        command = Keyword.put(command, :expr, opts[:eval])

        # TODO: commands with args
        struct!(EvalCommand, command)

      Keyword.has_key?(opts, :commands) ->
        if Enum.any?(opts[:commands], &Keyword.has_key?(&1, :commands)) do
          raise ArgumentError, message: "compound commands cannot be nested"
        end

        commands = Keyword.fetch!(opts, :commands)
        parsed_commands = parse(commands, release_name, os)
        command = Keyword.put(command, :commands, parsed_commands)

        struct!(CompoundCommand, command)

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
