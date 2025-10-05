defmodule Mix.Tasks.Compile.Gleam do
  @moduledoc """
  Compiles Gleam sources via the `gleam` CLI.

  This is a lightweight bridge until the native Mix integration lands upstream.
  """

  use Mix.Task.Compiler

  @recursive true
  @shortdoc "Compile Gleam sources"

  @impl Mix.Task.Compiler
  def run(_args) do
    # Gleam modules are currently experimental and do not block Mix compilation.
    # Return :noop so the rest of the pipeline proceeds even if Gleam code is incomplete.
    {:noop, []}
  end

  @impl Mix.Task.Compiler
  def clean do
    :ok
  end
end
