defmodule Expkg.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/simonmcconnell/expkg"

  def project do
    [
      app: :expkg,
      version: @version,
      elixir: "~> 1.13",
      deps: deps(),
      description: "Generate release executables",
      package: [
        links: %{
          "GitHub" => @source_url,
          "Zig" => "https://ziglang.org"
        },
        licenses: ["MIT"]
      ],
      docs: [
        main: "expkg",
        source_url: @source_url,
        source_ref: "v#{@version}",
        extras: ["CHANGELOG.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Expkg, []}
    ]
  end

  defp deps do
    []
  end
end
