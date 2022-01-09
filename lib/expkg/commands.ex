defmodule Expkg.Commands do
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
            commands: [Expkg.Commands.t()]
          }
  end

  defmodule EvalCommand do
    @enforce_keys [:name, :help, :expr]
    defstruct [:name, :help, :expr]

    @type t :: %__MODULE__{
            name: String.t(),
            help: String.t(),
            expr: String.t()
          }
  end

  defmodule RpcCommand do
    @enforce_keys [:name, :help, :expr]
    defstruct [:name, :help, :expr]

    @type t :: %__MODULE__{
            name: String.t(),
            help: String.t(),
            expr: String.t()
          }
  end

  alias __MODULE__.{Command, CompoundCommand, EvalCommand, RpcCommand}

  @type t :: Command.t() | CompoundCommand.t() | EvalCommand.t() | RpcCommand.t()
  @type arg_type :: :string | :integer | :float
  @type mod_fn_args :: {module(), atom(), [{arg_name :: atom(), arg_type}]}
  @type custom_command_option ::
          {:name, String.t()}
          | {:help, String.t()}
          | {:eval, String.t() | mfa()}
          | {:rpc, String.t() | mfa()}
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

  def default_commands do
    [
      :start,
      :start_iex,
      :service,
      :eval,
      :rpc,
      :remote,
      :restart,
      :stop,
      :pid,
      :version
    ]
  end

  @spec parse([command_option], release_name :: String.t(), os) :: [t()]
        when os: :windows | :darwin | :linux_musl | :linux
  def parse(commands, release_name, os) when is_list(commands) do
    do_parse(commands, [], release_name, os)
  end

  defp do_parse([], parsed, _release_name, _os), do: parsed |> List.flatten() |> Enum.reverse()

  defp do_parse([command | commands], parsed, release_name, os) do
    parsed_command = parse_command(command, release_name, os)
    do_parse(commands, [parsed_command | parsed], release_name, os)
    # case parse_command(command, release_name, os) do
    #   :skip ->
    #     do_parse(commands, parsed, release_name, os)

    #   # {:error, reason} ->
    #   #   raise ArgumentError,
    #   #     message: "failed to parse command '#{inspect(command)}': #{inspect(reason)}"

    #   parsed_command ->
    #     do_parse(commands, [parsed_command | parsed], release_name, os)
    # end
  end

  defp parse_command(command, release_name, os) when is_list(command) do
    name = Keyword.fetch!(command, :name)
    help = Keyword.fetch!(command, :help)

    cond do
      Keyword.has_key?(command, :rpc) ->
        validate_rpc_or_eval_command!(command[:rpc], :rpc)

        %RpcCommand{
          name: name,
          help: help,
          expr: command[:rpc]
        }

      Keyword.has_key?(command, :eval) ->
        validate_rpc_or_eval_command!(command[:eval], :eval)

        %EvalCommand{
          name: name,
          help: help,
          expr: command[:eval]
        }

      Keyword.has_key?(command, :commands) ->
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
      args: ["\"expr\""]
    }
  end

  defp parse_command(:rpc, _release_name, _os) do
    %Command{
      name: "rpc",
      help: "Executes the given expression remotely on the running system",
      args: ["\"expr\""]
    }
  end

  defp parse_command(:remote, _release_name, _os) do
    %Command{
      name: "remote",
      help: "Connects to the running system via a remote shell"
    }
  end

  defp parse_command(:service, release_name, :windows) do
    %CompoundCommand{
      name: "service",
      help: "Add, remove, start or stop the #{release_name} Windows Service",
      commands: [
        %Command{name: "add", help: "Add to Windows Services"},
        %Command{name: "remove", help: "Remove the service"},
        %Command{name: "start", help: "Start the service"},
        %Command{name: "stop", help: "Stop the service"}
      ]
    }
  end

  defp parse_command(:service, _release_name, _os), do: []

  defp parse_command(:daemon, _release_name, os) when os in [:darwin, :linux_musl, :linux] do
    raise("not implemented")
  end

  defp validate_rpc_or_eval_command!(fn_string, _rpc_or_eval)
       when is_binary(fn_string),
       do: :ok

  defp validate_rpc_or_eval_command!({m, f, a}, _rpc_or_eval)
       when is_atom(m) and is_atom(f) and is_list(a),
       do: :ok

  defp validate_rpc_or_eval_command!(_, rpc_or_eval),
    do: raise(ArgumentError, message: "#{rpc_or_eval} commands must be a string or MFA tuple")
end