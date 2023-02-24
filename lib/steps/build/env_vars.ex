defmodule Relexe.Steps.Build.EnvVars do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Step

  require EEx

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    app_path = File.cwd!()
    target_name = Atom.to_string(context.target.alias)

    output_dir =
      Path.join(app_path, [
        "relexe_out",
        "/#{target_name}",
        "/releases",
        "/#{context.mix_release.version}"
      ])

    create_dotenvs(context, output_dir)

    # remove the Mix Release files
    Path.join(output_dir, "env.bat") |> File.rm!()
    Path.join(output_dir, "env.sh") |> File.rm!()

    context
  end

  defp create_dotenvs(context, output_dir) do
    app_path = File.cwd!()

    default = """
    # Set the release to work across nodes.
    # RELEASE_DISTRIBUTION must be "sname" (local), "name" (distributed) or "none".
    # RELEASE_DISTRIBUTION=name
    # RELEASE_NODE=#{context.mix_release.name}
    """

    # create dotenv files from EEx templates
    dotenv_path = Path.join(output_dir, ".env")
    eex_path = Path.join(app_path, ["/rel", "/relexe", "/.env.#{context.target.os}.eex"])
    eex_file_exists? = File.exists?(eex_path)

    if eex_file_exists? do
      File.write!(dotenv_path, EEx.eval_file(eex_path, context: context))
    else
      File.write!(dotenv_path, default)
    end

    Enum.each(context.mix_release.options[:relexe][:commands], fn cmd ->
      create_command_dotenv_from_eex(context, output_dir, cmd)
    end)

    # create dotenv files from release config
    case context.mix_release.options[:relexe][:env][context.target.os] do
      opts when is_nil(opts) or opts == [] ->
        unless eex_file_exists?, do: File.write!(dotenv_path, default)

      opts ->
        {dotenv_opts, commands_opts} =
          Enum.split_with(opts, fn
            {command, command_opts} when is_atom(command) and is_list(command_opts) -> false
            {key, value} when is_atom(key) and is_binary(value) -> true
          end)

        create_dotenv(context, dotenv_path, dotenv_opts)

        Enum.each(commands_opts, fn {command, command_opts} ->
          command_dotenv_path = Path.join(output_dir, ".env.#{command}")
          create_dotenv(context, command_dotenv_path, command_opts)
        end)
    end
  end

  defp create_command_dotenv_from_eex(context, output_dir, command) do
    command_name =
      case command do
        name when is_atom(name) -> name
        name when is_binary(name) -> name
        {name, _opts} -> name
      end

    app_path = File.cwd!()

    eex_path =
      Path.join(app_path, [
        "/rel",
        "/relexe",
        "/.env.#{context.target.os}.#{command_name}.eex"
      ])

    if File.exists?(eex_path) do
      path = Path.join(output_dir, ".env.#{command_name}")
      File.write!(path, EEx.eval_file(eex_path, context: context))
    end
  end

  defp create_dotenv(context, path, [{k, v} | _] = env)
       when is_atom(k) and is_binary(v) do
    line_ending = if context.target.os == :windows, do: "\r\n", else: "\n"

    contents =
      env
      |> Enum.map(fn {key, value} ->
        contains_spaces? = String.contains?(value, " ")
        start_quote? = String.starts_with?(value, "\"")
        end_quote? = String.ends_with?(value, "\"")

        cond do
          not contains_spaces? ->
            "#{key}=#{value}"

          start_quote? and end_quote? ->
            "#{key}=#{value}"

          not start_quote? and not end_quote? ->
            ~s|#{key}="#{value}"|

          true ->
            raise ArgumentError,
                  "environment variables containing spaces must be enclosed in double quotes: #{value}"
        end
      end)
      |> Enum.join(line_ending)

    File.write!(path, contents)
  end
end
