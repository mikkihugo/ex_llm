defmodule Mix.Tasks.Gleam.Deps.Get do
  @moduledoc "Downloads Gleam dependencies for the embedded project"
  use Mix.Task

  @shortdoc "Fetch Gleam deps"

  @impl Mix.Task
  def run(_args) do
    Mix.GleamHelpers.run!(~w[deps download])
  end
end
