defmodule Singularity.BuildTools.NxTool do
  @moduledoc """
  NX Build Tool - Integration with NX build system.

  Implements @behaviour BuildToolType for NX monorepo automation.
  """

  @behaviour Singularity.Integration.BuildToolType

  require Logger

  @impl Singularity.Integration.BuildToolType
  def tool_type, do: :nx

  @impl Singularity.Integration.BuildToolType
  def description do
    "NX monorepo build system"
  end

  @impl Singularity.Integration.BuildToolType
  def capabilities do
    ["monorepo", "task_graph", "distributed_caching", "plugins", "fast_ci"]
  end

  @impl Singularity.Integration.BuildToolType
  def applicable?(project_path) when is_binary(project_path) do
    File.exists?(Path.join(project_path, "nx.json")) ||
      File.exists?(Path.join(project_path, "workspace.json"))
  end

  @impl Singularity.Integration.BuildToolType
  def run_build(project_path, _opts \\ []) when is_binary(project_path) do
    Logger.debug("NX: Running build", project_path: project_path)

    case run_nx_command(project_path, ["run-many", "--target=build"]) do
      {output, 0} ->
        Logger.info("NX build succeeded")
        {:ok, %{output: output, status: 0}}

      {output, status} ->
        Logger.error("NX build failed", status: status)
        {:error, {:build_failed, status, output}}
    end
  end

  @impl Singularity.Integration.BuildToolType
  def run_target(target, _opts \\ []) when is_binary(target) do
    Logger.debug("NX: Running target", target: target)

    case run_nx_command(".", ["run", target]) do
      {output, 0} ->
        Logger.info("NX target succeeded")
        {:ok, %{output: output, status: 0}}

      {output, status} ->
        Logger.error("NX target failed", status: status)
        {:error, {:target_failed, status, output}}
    end
  end

  @impl Singularity.Integration.BuildToolType
  def clean_build(project_path) when is_binary(project_path) do
    Logger.debug("NX: Cleaning build", project_path: project_path)

    case run_nx_command(project_path, ["reset"]) do
      {_output, 0} ->
        Logger.info("NX clean succeeded")
        :ok

      {output, status} ->
        Logger.error("NX clean failed", status: status)
        {:error, {:clean_failed, status, output}}
    end
  end

  defp run_nx_command(project_path, args) do
    cmd = "nx"

    case System.cmd(cmd, args, cd: project_path, stderr_to_stdout: true) do
      {output, 0} -> {output, 0}
      {output, status} -> {output, status}
    end
  rescue
    _e ->
      {"NX not found", 127}
  end
end
