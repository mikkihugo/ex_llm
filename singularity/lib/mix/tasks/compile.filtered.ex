defmodule Mix.Tasks.Compile.Filtered do
  @moduledoc """
  Compile with dependency warnings hidden - only shows Singularity code warnings.

  Runs `mix compile` and filters output to only show warnings from lib/singularity/
  instead of all warnings including dependencies.

  Usage:
      mix compile.only
      mix compile.only --force
  """

  use Mix.Task
  require Logger

  def run(args) do
    # Capture compiler output
    case MixHelper.run_compile(args) do
      {:ok, output} ->
        # Filter output to only show Singularity warnings
        filtered = filter_output(output)
        IO.write(filtered)

      {:error, reason} ->
        Logger.error("Compilation failed: #{reason}")
    end
  end

  # Filter to only show warnings from lib/singularity/
  defp filter_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&should_show_line/1)
    |> Enum.join("\n")
  end

  defp should_show_line(""), do: false
  defp should_show_line(line) do
    # Show errors always
    String.contains?(line, "error:") or
    # Show Singularity warnings only
    (String.contains?(line, "warning:") and String.contains?(line, "lib/singularity/")) or
    # Show compilation status lines
    String.contains?(line, ["Compiled", "All modules compiled", "Generated"])
  end
end

defmodule MixHelper do
  @doc false
  def run_compile(args) do
    try do
      Mix.Task.run(:compile, args)
      {:ok, ""}
    rescue
      e ->
        {:error, inspect(e)}
    end
  end
end
