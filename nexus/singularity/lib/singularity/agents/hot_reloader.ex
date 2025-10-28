defmodule Singularity.Agents.HotReloader do
  @moduledoc """
  Utilities to trigger a project recompile / hot reload.

  NOTE: By default this performs a dry-run and only returns the commands it would run.
  Actual compilation/reload requires `run: true` in opts and will call `Mix.Task.run("compile")`.
  """

  require Logger

  @default_opts [run: false]

  @doc "Return the shell commands that would be run to recompile the project in this dir."
  def compile_commands(cwd \\ ".") do
    ["cd #{cwd}", "mix compile"]
  end

  @doc "Trigger a Mix compile. By default dry-run; to actually run pass run: true."
  def trigger_compile(cwd \\ ".", opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    if opts[:run] do
      Logger.info("Running mix compile in #{cwd}")
      # run in spawned OS process to avoid interfering with caller VM
      {out, exit} = System.cmd("mix", ["compile"], cd: cwd, into: IO.stream(:stdio, :line))
      {:ok, exit, out}
    else
      {:ok, :dry_run, compile_commands(cwd)}
    end
  end
end
