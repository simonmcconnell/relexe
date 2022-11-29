defmodule Relexe do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  alias Burrito.Builder.Log
  alias Burrito.Builder
  alias Relexe.Steps.Build.{PackAndBuild, CopyRelease, EnvVars}

  @spec assemble(Mix.Release.t()) :: Mix.Release.t()
  def assemble(%Mix.Release{options: options} = release) do
    pre_check(release)

    burrito_options = [
      phases: [
        build: [PackAndBuild, CopyRelease, EnvVars]
      ],
      extra_steps: options[:relexe][:extra_steps] || [],
      targets: options[:relexe][:targets] || []
    ]

    options =
      options
      |> Keyword.put(:burrito, burrito_options)
      |> Keyword.put(:quiet, true)

    release = %Mix.Release{release | options: options}

    Builder.build(release)
  end

  defp pre_check(release) do
    if Enum.any?(~w(zig 7z), &(System.find_executable(&1) == nil)) do
      Log.error(
        :build,
        "You MUST have `zig` and `7zip` installed to use relexe, we couldn't find it in your PATH!"
      )

      exit(1)
    end

    # default_command
    if release.options[:relexe][:default_command] not in [nil, :start, :help] do
      Log.error(:build, "If set, default_command must be either :start or :help")
      exit(1)
    end
  end
end
