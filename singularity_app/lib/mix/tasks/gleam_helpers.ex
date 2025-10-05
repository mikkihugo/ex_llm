defmodule Mix.GleamHelpers do
  @moduledoc false

  @spec run!(nonempty_list(String.t())) :: :ok | {:noop, String.t()}
  def run!(args) do
    case System.cmd(gleam_executable!(), args,
           cd: gleam_project_root(), stderr_to_stdout: true
         ) do
      {output, 0} ->
        if String.trim(output) != "" do
          Mix.shell().info(output)
        end

        :ok

      {output, 1} ->
        if String.contains?(output, "No files matched the provided limit.") do
          {:noop, output}
        else
          Mix.raise("gleam #{Enum.join(args, " ")} failed:\n#{output}")
        end

      {output, status} ->
        Mix.raise("gleam #{Enum.join(args, " ")} exited with status #{status}:\n#{output}")
    end
  end

  defp gleam_executable! do
    System.find_executable("gleam") || Mix.raise("could not find the `gleam` executable in PATH")
  end

  defp gleam_project_root do
    cwd = File.cwd!()

    cond do
      File.dir?(Path.join(cwd, "gleam")) ->
        Path.join(cwd, "gleam")

      File.dir?(Path.join(cwd, "singularity_app/gleam")) ->
        Path.join(cwd, "singularity_app/gleam")

      true ->
        Mix.raise("could not locate the Gleam project directory (expected ./gleam)")
    end
  end
end
