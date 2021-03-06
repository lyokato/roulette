defmodule Roulette.Mixfile do
  use Mix.Project

  def project do
    [
      app: :roulette,
      version: "1.0.5",
      elixir: "~> 1.6",
      package: package(),
      start_permanent: Mix.env == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :ex_hash_ring,
        :fastglobal,
        :logger,
        :gnat,
        :poolboy
      ]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.15", only: :dev, runtime: false},
      {:credo, "~> 0.3", only: :dev, runtime: false},
      {:mock, "~> 0.3.0", only: :test},
      {:ex_hash_ring, "~> 3.0"},
      {:fastglobal, "~> 1.0"},
      {:gnat, "~> 0.4.1"},
      {:poolboy, "~> 1.5"}
    ]
  end

  defp package() do
    [
      description: "Scalable PubSub client for HashRing-ed gnatsd-cluster",
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/lyokato/roulette",
        "Docs"   => "https://hexdocs.pm/roulette"
      },
      maintainers: ["Lyo Kato"]
    ]
  end
end
