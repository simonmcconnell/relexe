defmodule Expkg.MixProject do
  use Mix.Project

  @version String.trim(File.read!("VERSION"))
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
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    [
      {:burrito, github: "burrito-elixir/burrito"}
    ]
  end
end
