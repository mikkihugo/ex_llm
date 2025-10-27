defmodule Singularity.BuildTools.MoonTool do
  @moduledoc """
  Moon Build Tool - Integration with Moon build system.

  Implements @behaviour BuildToolType for Moon polyglot build automation.
  """

  @behaviour Singularity.Integration.BuildToolType

  require Logger

  @impl Singularity.Integration.BuildToolType
  def tool_type, do: :moon

  @impl Singularity.Integration.BuildToolType
  def description do
    "Moon build orchestration system"
  end

  @impl Singularity.Integration.BuildToolType
  def capabilities do
    ["polyglot", "task_orchestration", "caching", "vcs_aware", "ci_aware"]
  end

  @impl Singularity.Integration.BuildToolType
  def applicable?(project_path) when is_binary(project_path) do
    File.exists?(Path.join(project_path, ".moon.yml")) ||
      File.exists?(Path.join(project_path, "moon.yml"))
  end

  @impl Singularity.Integration.BuildToolType
  def run_build(project_path, opts \\ []) when is_binary(project_path) do
    Logger.debug("Moon: Running build", project_path: project_path)

    case run_moon_command(project_path, ["run", ":build"]) do
      {output, 0} ->
        Logger.info("Moon build succeeded")
        {:ok, %{output: output, status: 0}}

      {output, status} ->
        Logger.error("Moon build failed", status: status)
        {:error, {:build_failed, status, output}}
    end
  end

  @impl Singularity.Integration.BuildToolType
  def run_target(target, opts \\ []) when is_binary(target) do
    Logger.debug("Moon: Running target", target: target)

    case run_moon_command(".", ["run", target]) do
      {output, 0} ->
        Logger.info("Moon target succeeded")
        {:ok, %{output: output, status: 0}}

      {output, status} ->
        Logger.error("Moon target failed", status: status)
        {:error, {:target_failed, status, output}}
    end
  end

  @impl Singularity.Integration.BuildToolType
  def clean_build(project_path) when is_binary(project_path) do
    Logger.debug("Moon: Cleaning build", project_path: project_path)

    case run_moon_command(project_path, ["clean"]) do
      {_output, 0} ->
        Logger.info("Moon clean succeeded")
        :ok

      {output, status} ->
        Logger.error("Moon clean failed", status: status)
        {:error, {:clean_failed, status, output}}
    end
  end

  defp run_moon_command(project_path, args) do
    cmd = "moon"

    case System.cmd(cmd, args, cd: project_path, stderr_to_stdout: true) do
      {output, 0} -> {output, 0}
      {output, status} -> {output, status}
    end
  rescue
    _e ->
      {"Moon not found", 127}
  end
end
