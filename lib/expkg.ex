defmodule Expkg do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  alias Burrito.Builder.Log
  alias Expkg.Builder

  @spec pack(Mix.Release.t()) :: Mix.Release.t()
  def pack(%Mix.Release{} = release) do
    pre_check(release)
    Builder.build(release)
  end

  defp pre_check(release) do
    if Enum.any?(~w(zig 7z), &(System.find_executable(&1) == nil)) do
      Log.error(
        :build,
        "You MUST have `zig` and `7zip` installed to use expkg, we couldn't find it in your PATH!"
      )

      exit(1)
    end

    # no_args_command
    if release.options[:expkg][:no_args_command] not in [nil, :start, :help] do
      Log.error(:build, "no_args_command must be either :start or :help")
      exit(1)
    end
  end
end
