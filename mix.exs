defmodule Amlapio.Mixfile do
  use Mix.Project

  @version "0.2.0"

  def project do
    [app: :amlapio,
     version: @version,
     elixir: "~> 1.4",
     description: description(),
     package: package(),
     source_url: "https://github.com/ianrumford/amlapio",
     homepage_url: "https://github.com/ianrumford/amlapio",
     docs: [extras: ["./README.md", "./CHANGELOG.md"]],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:gen_mqtt, "~> 0.3.1", only: [:test]},
      {:ex_doc, "~> 0.14.5", only: :dev},
    ]
  end

  defp package do
    [maintainers: ["Ian Rumford"],
     files: ["lib", "mix.exs", "README*", "LICENSE*", "CHANGELOG*"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/ianrumford/amlapio"}]
  end

  defp description do
  """
  Amlapio: Adding a Map API to a GenServer or Module with Agent-held State

  A use macro to add a Map API (e.g. get, put, pop, etc) to a GenServer's
  state or a module's state held in an Agent.
  """
  end

end
