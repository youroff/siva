defmodule Siva.Mixfile do
  use Mix.Project

  def project, do: [
    app: :siva,
    version: "0.1.0",
    elixir: "~> 1.4",
    build_embedded: Mix.env == :prod,
    start_permanent: Mix.env == :prod,
    deps: deps()
  ]

  def application, do: [
    extra_applications: [:logger],
    mod: {Siva, []}
  ]

  defp deps, do: [
    {:monex, "~> 0.1.5"}
  ]
end
