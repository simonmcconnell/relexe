defmodule Relexe.Steps.Build.PackAndBuild.Commands do
  defmodule Command do
    @enforce_keys [:name, :help]
    defstruct [:name, :help, args: []]

    @type t :: %__MODULE__{
            name: String.t(),
            help: String.t(),
            args: [String.t()]
          }
  end

  defmodule CompoundCommand do
    @enforce_keys [:name, :help]
    defstruct [:name, :help, args: [], commands: []]

    @type t :: %__MODULE__{
            name: String.t(),
            help: String.t(),
            commands: [Relexe.Commands.t()]
          }
  end

  defmodule EvalCommand do
    @enforce_keys [:name, :help, :expr]
    defstruct [:name, :help, :expr]

    @type t :: %__MODULE__{
            name: String.t(),
            help: String.t(),
            expr: String.t() | Commands.mod_fn_args()
          }
  end

  defmodule RpcCommand do
    @enforce_keys [:name, :help, :expr]
    defstruct [:name, :help, :expr]

    @type t :: %__MODULE__{
            name: String.t(),
            help: String.t(),
            expr: String.t() | Commands.mod_fn_args()
          }
  end

  alias __MODULE__.{Command, CompoundCommand, EvalCommand, RpcCommand}
  alias Burrito.Builder.Log

  @type t :: Command.t() | CompoundCommand.t() | EvalCommand.t() | RpcCommand.t()
  @type arg_type :: :string | :integer | :float
  @type mod_fn_args :: {module(), atom(), [{arg_name :: atom(), arg_type}]}
  @type custom_command_option ::
          {:name, String.t()}
          | {:help, String.t()}
          | {:eval, String.t() | mod_fn_args()}
          | {:rpc, String.t() | mod_fn_args()}
  @type custom_command :: [custom_command_option]
  @type command_option ::
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

  def default, do: ~w(start start_iex service eval rpc remote restart stop pid version)a

  @spec parse([command_option], release_name :: String.t(), os) :: [t()]
        when os: :windows | :darwin | :linux
  def parse(commands, release_name, os) when is_list(commands) do
    Log.info(:step, "Parsing CLI commands")
    do_parse(commands, [], release_name, os)
  end

  defp do_parse([], parsed, _release_name, _os), do: parsed |> List.flatten() |> Enum.reverse()

  defp do_parse([command | commands], parsed, release_name, os) do
    parsed_command = parse_command(command, release_name, os)
    do_parse(commands, [parsed_command | parsed], release_name, os)
  end

  defp parse_command(command, release_name, os) when is_list(command) do
    name = Keyword.fetch!(command, :name)
    help = Keyword.fetch!(command, :help)

    cond do
      Keyword.has_key?(command, :rpc) ->
        validate_rpc_or_eval_command!(command[:rpc], :rpc)

        # TODO: commands with args
        %RpcCommand{
          name: name,
          help: help,
          expr: command[:rpc]
        }

      Keyword.has_key?(command, :eval) ->
        validate_rpc_or_eval_command!(command[:eval], :eval)

        # TODO: commands with args
        %EvalCommand{
          name: name,
          help: help,
          expr: command[:eval]
        }

      Keyword.has_key?(command, :commands) ->
        nested_compound_commands? =
          Enum.any?(command[:commands], &Keyword.has_key?(&1, :commands))

        if nested_compound_commands? do
          raise ArgumentError, message: "compound commands cannot be nested"
        end

        %CompoundCommand{
          name: name,
          help: help,
          commands: parse(command[:commands], release_name, os)
        }

      true ->
        raise ArgumentError, message: "custom commands must contain an :rpc or :eval option"
    end
  end

  defp parse_command(:start, release_name, _os) do
    %Command{
      name: "start",
      help: "Start #{release_name}"
    }
  end

  defp parse_command(:start_iex, release_name, _os) do
    %Command{
      name: "start_iex",
      help: "Start #{release_name} with IEx attached"
    }
  end

  defp parse_command(:stop, release_name, _os) do
    %Command{
      name: "stop",
      help: "Stop #{release_name}"
    }
  end

  defp parse_command(:restart, release_name, _os) do
    %Command{
      name: "restart",
      help: "Restart #{release_name}"
    }
  end

  defp parse_command(:pid, _release_name, _os) do
    %Command{
      name: "pid",
      help: "Prints the operating system PID of the running system"
    }
  end

  defp parse_command(:version, _release_name, _os) do
    %Command{
      name: "version",
      help: "Print the application version"
    }
  end

  defp parse_command(:eval, _release_name, _os) do
    %Command{
      name: "eval",
      help: "Executes the given expression on a new, non-booted system",
      args: ["expr"]
    }
  end

  defp parse_command(:rpc, _release_name, _os) do
    %Command{
      name: "rpc",
      help: "Executes the given expression remotely on the running system",
      args: ["expr"]
    }
  end

  defp parse_command(:remote, _release_name, _os) do
    %Command{
      name: "remote",
      help: "Connects to the running system via a remote shell"
    }
  end

  defp parse_command(service_or_daemon, release_name, :windows)
       when service_or_daemon in [:daemon, :service] do
    %CompoundCommand{
      name: "service",
      help: "Add, remove, start or stop the #{release_name} Windows Service",
      commands: [
        %Command{name: "add", help: "Add Windows Service"},
        %Command{name: "remove", help: "Remove the service"},
        %Command{name: "start", help: "Start the service"},
        %Command{name: "stop", help: "Stop the service"}
      ]
    }
  end

  defp parse_command(service_or_daemon, _release_name, _os)
       when service_or_daemon in [:daemon, :service] do
    raise("not implemented")
  end

  defp validate_rpc_or_eval_command!(fn_string, _rpc_or_eval)
       when is_binary(fn_string),
       do: :ok

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
