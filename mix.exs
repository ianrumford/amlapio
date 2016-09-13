defmodule Amlapio.Mixfile do
  use Mix.Project

  def project do
    [app: :amlapio,
     version: "0.1.0",
     elixir: "~> 1.3",
     description: description,
     package: package,
     source_url: "https://github.com/ianrumford/elixir_amlapio",
     homepage_url:
     "https://github.com/ianrumford/elixir_amlapio",
     docs: [extras: ["./docs/README.md"]],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, ">= 0.13.0", only: :dev}]
  end

  defp package do
    [maintainers: ["Ian Rumford"],
     files: ["lib", "mix.exs", "README*", "LICENSE*"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/ianrumford/elixir_amlapio"}]
  end
  
  defp description do
  """
  Amlapio: Adding a Map API to a GenServer or Module with Agent-held State

  A __using__ macro to add a Map API (e.g. get, put, pop, etc) to a GenServer's
  state or the state held in an Agent.

  Amlapio is the Welsh word to "wrap"

  """     
  end
  
end
