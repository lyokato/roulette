defmodule Roulette.Mixfile do
  use Mix.Project

  def project do
    [
      app: :roulette,
      version: "0.2.2",
      elixir: "~> 1.5",
      package: package(),
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :ex_hash_ring,
        :fastglobal,
        :logger,
        :gnat,
        :gproc,
        :poolboy
      ]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.15", only: :dev, runtime: false},
      {:ex_hash_ring, "~> 1.0"},
      {:fastglobal, "~> 1.0"},
      {:gnat, "~> 0.4.1"},
      {:gproc, "~> 0.6.1"},
      {:poolboy, "~> 1.5"}
    ]
  end

  defp package() do
    [
      description: "HashRing supported gnatsd client",
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/lyokato/roulette",
        "Docs"   => "https://hexdocs.pm/roulette"
      },
      maintainers: ["Lyo Kato"]
    ]
  end
end
