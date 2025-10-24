defmodule CodeEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :code_engine,
      version: "1.0.0",
      elixir: "~> 1.18",
      compilers: [:rustler | Mix.compilers()],
      rustler_crates: [code_engine: [skip_compilation?: true]],
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [{:rustler, "~> 0.37", runtime: false}]
  end
end