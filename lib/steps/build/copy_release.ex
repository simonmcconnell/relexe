defmodule Relexe.Steps.Build.CopyRelease do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Step

  @behaviour Step

  @success_banner """
  \n\n
  ----> relexe delivered!
  """

  @impl Step
  def execute(%Context{} = context) do
    release_name = Atom.to_string(context.mix_release.name)
    executable_name = release_name
    target_name = Atom.to_string(context.target.alias)

    bin_name =
      if context.target.os == :windows do
        executable_name <> ".exe"
      else
        executable_name
      end

    # move the compiled binary to the output directory
    bin_path = Path.join(context.self_dir, ["zig-out", "/bin", "/#{bin_name}"])
    bin_out_dir = Path.join(context.mix_release.path, "bin")
    bin_out_path = Path.join(bin_out_dir, bin_name)

    File.mkdir_p!(bin_out_dir)
    File.copy!(bin_path, bin_out_path)
    File.rm!(bin_path)

    # Mark resulting bin as executable
    File.chmod!(bin_out_path, 0o744)

    # remove unrequired Mix Release files
    Path.join(context.mix_release.path, ["bin/", release_name]) |> File.rm!()
    Path.join(context.mix_release.path, ["bin/", release_name <> ".bat"]) |> File.rm!()
    Path.join(context.mix_release.version_path, "elixir") |> File.rm!()
    Path.join(context.mix_release.version_path, "elixir.bat") |> File.rm!()
    Path.join(context.mix_release.version_path, "iex") |> File.rm!()
    Path.join(context.mix_release.version_path, "iex.bat") |> File.rm!()

    # Copy the release to relexe_out/<target>
    app_path = File.cwd!()
    target_out_path = Path.join(app_path, ["relexe_out", "/#{target_name}"])
    File.mkdir_p!(target_out_path)
    File.cp_r!(context.mix_release.path, target_out_path)

    # TODO: flesh out the output, so it gives more detailed instructions ala Mix Release
    IO.puts(@success_banner <> "\tOutput Path: #{target_out_path}\n\n")

    context
  end
end
