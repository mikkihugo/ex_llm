defmodule Singularity.BuildTools.BazelTool do
  @moduledoc """
  Bazel Build Tool - Integration with Bazel build system.

  Implements @behaviour BuildToolType for Bazel build automation.
  """

  @behaviour Singularity.Integration.BuildToolType

  require Logger

  @impl Singularity.Integration.BuildToolType
  def tool_type, do: :bazel

  @impl Singularity.Integration.BuildToolType
  def description do
    "Bazel build system integration"
  end

  @impl Singularity.Integration.BuildToolType
  def capabilities do
    ["monorepo", "caching", "parallel_builds", "remote_execution", "incremental"]
  end

  @impl Singularity.Integration.BuildToolType
  def applicable?(project_path) when is_binary(project_path) do
    File.exists?(Path.join(project_path, "WORKSPACE")) ||
      File.exists?(Path.join(project_path, "WORKSPACE.bazel")) ||
      File.exists?(Path.join(project_path, "BUILD.bazel"))
  end

  @impl Singularity.Integration.BuildToolType
  def run_build(project_path, opts \\ []) when is_binary(project_path) do
    Logger.debug("Bazel: Running build", project_path: project_path)

    case run_bazel_command(project_path, ["build", "//:all"]) do
      {output, 0} ->
        Logger.info("Bazel build succeeded")
        {:ok, %{output: output, status: 0}}

      {output, status} ->
        Logger.error("Bazel build failed", status: status)
        {:error, {:build_failed, status, output}}
    end
  end

  @impl Singularity.Integration.BuildToolType
  def run_target(target, opts \\ []) when is_binary(target) do
    Logger.debug("Bazel: Running target", target: target)

    case run_bazel_command(".", ["build", target]) do
      {output, 0} ->
        Logger.info("Bazel target succeeded")
        {:ok, %{output: output, status: 0}}

      {output, status} ->
        Logger.error("Bazel target failed", status: status)
        {:error, {:target_failed, status, output}}
    end
  end

  @impl Singularity.Integration.BuildToolType
  def clean_build(project_path) when is_binary(project_path) do
    Logger.debug("Bazel: Cleaning build", project_path: project_path)

    case run_bazel_command(project_path, ["clean"]) do
      {_output, 0} ->
        Logger.info("Bazel clean succeeded")
        :ok

      {output, status} ->
        Logger.error("Bazel clean failed", status: status)
        {:error, {:clean_failed, status, output}}
    end
  end

  defp run_bazel_command(project_path, args) do
    cmd = "bazel"

    case System.cmd(cmd, args, cd: project_path, stderr_to_stdout: true) do
      {output, 0} -> {output, 0}
      {output, status} -> {output, status}
    end
  rescue
    _e ->
      {"Bazel not found", 127}
  end
end
