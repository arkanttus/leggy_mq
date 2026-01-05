defmodule Leggy.MixProject do
  use Mix.Project

  def project do
    [
      app: :leggy,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [:ex_unit, :mix, :amqp, :poolboy],
        list_unused_filters: true,
        # we use the following opt to change the PLT path
        # even though the opt is marked as deprecated, this is the doc-recommended way
        # to do this
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poolex, "~> 1.4.2"},
      {:amqp, "~> 4.0"},

      # Testing and Dev Tools
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
