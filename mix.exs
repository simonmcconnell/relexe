defmodule Expkg.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()
  @source_url "https://github.com/simonmcconnell/expkg"

  def project do
    [
      app: :expkg,
      version: @version,
      elixir: "~> 1.13",
      deps: deps(),
      description: "Generate custom release executables (not scripts)",
      package: [
        links: %{
          "GitHub" => @source_url,
          "Zig" => "https://ziglang.org",
          "Burrito" => "https://github.com/burrito-elixir/burrito"
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
      {:burrito, github: "simonmcconnell/burrito", ref: "f009f35"}
    ]
  end
end
