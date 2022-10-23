defmodule LambdaCh.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:exsync, "~> 0.2", only: :dev},
      {:freedom_formatter, ">= 2.0.0", runtime: false},
      {:typed_struct,
       git: "https://github.com/gusbicalho/typed_struct.git", ref: "a1e60cd9e66c07b168b8d457d65ae211cef4f0e5"},
    ]
  end
end
