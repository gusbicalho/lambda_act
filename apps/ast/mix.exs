defmodule AST.MixProject do
  use Mix.Project

  def project do
    [
      app: :ast,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:typed_struct,
       git: "https://github.com/gusbicalho/typed_struct.git", ref: "a1e60cd9e66c07b168b8d457d65ae211cef4f0e5"},
    ]
  end
end
