defmodule Bioflow.MixProject do
  use Mix.Project

  def project do
    [
      app: :bioflow,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Bioflow.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:libcluster, "~> 3.5"},
      {:horde, "~> 0.8.7"},
      {:flow, "~> 1.2"}
    ]
  end
end
