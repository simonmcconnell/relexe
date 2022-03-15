defmodule Relexe.Steps.Build.PackAndBuild do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step
  alias Burrito.Builder.Target
  alias Relexe.Steps.Build.PackAndBuild.Commands
  alias Relexe.Steps.Build.PackAndBuild.Help

  require EEx

  @behaviour Step

  EEx.function_from_file(:def, :build_zig, "build.zig.eex", [:assigns])
  EEx.function_from_file(:def, :main_zig, "src/main.zig.eex", [:assigns])

  @impl Step
  def execute(%Context{} = context) do
    options = context.mix_release.options[:relexe] || []
    build_triplet = Target.make_triplet(context.target)

    assigns = assigns(context)

    self_path =
      __ENV__.file
      |> Path.dirname()
      |> Path.split()
      |> List.delete_at(-1)
      |> List.delete_at(-1)
      |> List.delete_at(-1)
      |> Path.join()
      |> Path.expand()

    context = %Context{context | self_dir: self_path}

    # create zig files from templates
    Path.join([context.self_dir, "build.zig"]) |> File.write!(build_zig(assigns))
    Path.join([context.self_dir, "src", "main.zig"]) |> File.write!(main_zig(assigns))

    # TODO: plugins
    # plugin_path = maybe_get_plugin_path(options[:plugin])

    zig_build_args =
      if context.target.debug? do
        ["-Dtarget=#{build_triplet}"]
      else
        ["-Dtarget=#{build_triplet}", "-Drelease-small=true"]
      end

    create_metadata_file(context.self_dir, zig_build_args, context.mix_release)

    # TODO: Why do we need to do this???
    # This is to bypass a VERY strange bug inside Linux containers...
    # If we don't do this, the archiver will fail to see all the files inside the lib directory
    # This is still under investigation, but touching a file inside the directory seems to force the
    # File system to suddenly "wake up" to all the files inside it.
    Path.join(context.work_dir, ["/lib", "/.relexe"]) |> File.touch!()

    build_result =
      System.cmd("zig", ["build"] ++ zig_build_args,
        cd: context.self_dir,
        # env: [
        #   {"__RELEXE_IS_PROD", is_prod?()},
        #   {"__RELEXE_RELEASE_PATH", context.work_dir},
        #   {"__RELEXE_RELEASE_NAME", release_name},
        #   {"__RELEXE_PLUGIN_PATH", plugin_path}
        # ],
        into: IO.stream()
      )

    if !options[:no_clean] do
      clean_build(context.self_dir)
    end

    case build_result do
      {_, 0} ->
        System.cmd("zig", ["fmt", "build.zig", "src"], cd: context.self_dir, into: IO.stream())
        context

      _ ->
        Log.error(
          :step,
          "Relexe failed to build your app! Check the logs for more information."
        )

        raise "Relexe build failed"
    end
  end

  def assigns(%Context{} = context) do
    options = context.mix_release.options[:relexe] || []
    commands_spec = options[:commands] || Commands.default()
    release_name = Atom.to_string(context.mix_release.name)
    commands = Commands.parse(commands_spec, release_name, context.target.os)

    %{
      allow_eval: options[:allow_eval] || true,
      allow_rpc: options[:allow_rpc] || true,
      commands: commands,
      executable_name: options[:executable_name] || release_name,
      help: Help.generate(context, commands),
      hide: options[:hide] || [],
      no_args_command: options[:no_args_command] || :help,
      release_name: release_name
    }
  end

  # defp maybe_get_plugin_path(nil), do: nil

  # defp maybe_get_plugin_path(plugin_path) do
  #   Path.join(File.cwd!(), [plugin_path])
  # end

  defp create_metadata_file(self_path, args, release) do
    Log.info(:step, "Generating wrapper metadata file...")

    {zig_version_string, 0} = System.cmd("zig", ["version"], cd: self_path)

    metadata_map = %{
      app_name: Atom.to_string(release.name),
      zig_version: zig_version_string |> String.trim(),
      zig_build_arguments: args,
      app_version: release.version,
      options: inspect(release.options),
      erts_version: release.erts_version |> to_string()
    }

    encoded = Jason.encode!(metadata_map)

    Path.join(self_path, "_metadata.json") |> File.write!(encoded)
  end

  # defp is_prod?() do
  #   if Mix.env() == :prod do
  #     "1"
  #   else
  #     "0"
  #   end
  # end

  defp clean_build(self_path) do
    Log.info(:step, "Cleaning up...")

    cache = Path.join(self_path, "zig-cache")
    out = Path.join(self_path, "zig-out")
    metadata = Path.join(self_path, "_metadata.json")

    File.rmdir(cache)
    File.rmdir(out)
    File.rm(metadata)

    :ok
  end

  # *.zig.eex helpers

  defp args_substitutions(args) when is_list(args) do
    1..length(args)
    |> Enum.map(fn _ -> ~S|\"{s}\"| end)
    |> Enum.join(", ")
  end

  defp args_string(args) when is_list(args) do
    args
    |> Enum.map(fn arg -> "\"#{arg}\"" end)
    |> Enum.join(", ")
  end
end
