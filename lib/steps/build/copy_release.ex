defmodule Relexe.Steps.Build.CopyRelease do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Step

  @behaviour Step

  @success_banner """
  \n\n
  ----> relexe delivered! 📦📦📦
  """

  @impl Step
  def execute(%Context{} = context) do
    release_name = Atom.to_string(context.mix_release.name)
    executable_name = context.mix_release.options[:relexe][:executable_name] || release_name
    target_name = Atom.to_string(context.target.alias)

    orig_bin_name =
      if context.target.os == :windows do
        "#{executable_name}.exe"
      else
        executable_name
      end

    bin_name =
      if context.target.os == :windows do
        "#{executable_name}_#{target_name}.exe"
      else
        "#{executable_name}_#{target_name}"
      end

    # TODO: copy the executable to the build directory, or copy the release directory to `relexe_out` and put the proper executable in the proper folder

    # remove unrequired Mix Release files
    Path.join(context.mix_release.path, ["bin/", release_name]) |> File.rm!()
    Path.join(context.mix_release.path, ["bin/", release_name <> ".bat"]) |> File.rm!()
    Path.join(context.mix_release.version_path, "elixir") |> File.rm!()
    Path.join(context.mix_release.version_path, "elixir.bat") |> File.rm!()
    Path.join(context.mix_release.version_path, "iex") |> File.rm!()
    Path.join(context.mix_release.version_path, "iex.bat") |> File.rm!()

    bin_path = Path.join(context.self_dir, ["zig-out", "/bin", "/#{orig_bin_name}"])
    bin_out_dir = Path.join(context.mix_release.path, "bin")
    bin_out_path = Path.join(bin_out_dir, bin_name)

    File.mkdir_p!(bin_out_dir)

    File.copy!(bin_path, bin_out_path)
    File.rm!(bin_path)

    # Mark resulting bin as executable
    File.chmod!(bin_out_path, 0o744)

    IO.puts(@success_banner <> "\tOutput Path: #{bin_out_path}\n\n")

    context
  end
end
