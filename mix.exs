defmodule Relexe.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()
  @source_url "https://github.com/simonmcconnell/relexe"

  def project do
    [
      app: :relexe,
      version: @version,
      elixir: "~> 1.13",
      deps: deps(),
      description: "Generate custom release executables (i.e. not scripts) with a CLI",
      package: [
        links: %{
          "GitHub" => @source_url,
          "Zig" => "https://ziglang.org",
          "Burrito" => "https://github.com/burrito-elixir/burrito"
        },
        licenses: ["MIT"]
      ],
      docs: [
        main: "relexe",
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
