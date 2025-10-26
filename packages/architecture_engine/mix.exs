## Enforce using the nix-provided Elixir for local development.
## This prevents accidental use of system/Homebrew Elixir which can
## cause compilation and test inconsistencies. CI can bypass this
## by setting the CI env var, and developers can opt out by
## setting ALLOW_SYSTEM_ELIXIR=1 (not recommended).

case System.find_executable("elixir") do
  nil -> :ok
  elixir_path ->
    in_nix = String.contains?(elixir_path, "/nix/store/")
    ci = System.get_env("CI")
    allow = System.get_env("ALLOW_SYSTEM_ELIXIR")

    unless in_nix or ci == "true" or allow == "1" do
      IO.puts("\nERROR: Detected elixir at: #{elixir_path}\n")
      IO.puts("This project requires running Elixir from the Nix dev-shell (nix develop / direnv allow).\n")
      IO.puts("Please start a nix dev-shell or set ALLOW_SYSTEM_ELIXIR=1 to bypass this check.\n")
      System.halt(1)
    end
end

defmodule ArchitectureEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :architecture_engine,
      version: "1.0.0",
      elixir: "~> 1.19",
      compilers: [:rustler | Mix.compilers()],
      rustler_crates: [architecture_engine: [skip_compilation?: true]],
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:rustler, "~> 0.37", runtime: false}
    ]
  end
end