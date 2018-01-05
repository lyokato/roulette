defmodule Roulette.Mixfile do
  use Mix.Project

  def project do
    [
      app: :roulette,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :gproc
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_hash_ring, "~> 1.0"},
      {:poolboy, "~> 1.5"},
      {:fastglobal, "~> 1.0"},
      {:gnat, "~> 0.4.1"},
      {:gproc, "~> 0.6.1"}
    ]
  end
end
