defmodule Singularity.Integration.BuildToolOrchestrator do
  @moduledoc """
  Build Tool Orchestrator - Config-driven orchestration of build tool strategies.

  Automatically discovers and uses enabled build tools to run build commands using the most
  appropriate tool for the project (Bazel, NX, Moon, etc.).

  Routes build commands to first-applicable-match build tool based on project structure and tool capabilities.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Integration.BuildToolOrchestrator",
    "purpose": "Config-driven orchestration of build tool strategies",
    "layer": "integration",
    "status": "production"
  }
  ```

  ## Usage

  ```elixir
  # Run build with automatic tool detection
  BuildToolOrchestrator.run_build("/path/to/project")
  # => {:ok, %{output: "...", status: 0}}

  # Run specific target
  BuildToolOrchestrator.run_target("//apps/api:build")
  # => {:ok, %{output: "...", status: 0}}

  # Get available tools
  BuildToolOrchestrator.get_tools_info()
  # => [%{name: :bazel, enabled: true, priority: 10, ...}, ...]
  ```
  """

  require Logger
  alias Singularity.Integration.BuildToolType

  @doc """
  Run build command with automatic tool detection.

  Tries build tools in priority order until one succeeds.

  ## Parameters

  - `project_path`: Path to project root
  - `opts`: Optional keyword list

  ## Returns

  - `{:ok, %{output: ..., status: 0}}` - Build successful
  - `{:error, :no_tool_found}` - No applicable tool found
  - `{:error, reason}` - Build failed
  """
  def run_build(project_path, opts \\ []) when is_binary(project_path) do
    try do
      tools = load_tools_for_attempt(opts)

      Logger.info("BuildToolOrchestrator: Running build",
        project_path: project_path,
        tool_count: length(tools)
      )

      case try_build_tools(tools, project_path, opts) do
        {:ok, result} ->
          Logger.info("Build successful",
            project_path: project_path,
            status: result[:status]
          )

          {:ok, result}

        {:error, :no_tool_found} ->
          Logger.warning("No applicable build tool found",
            project_path: project_path
          )

          {:error, :no_tool_found}

        error ->
          error
      end
    rescue
      e ->
        Logger.error("Build orchestration failed",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {:error, :build_failed}
    end
  end

  @doc """
  Run specific target using appropriate build tool.

  ## Parameters

  - `target`: Target to build (e.g., "//apps/api:build")
  - `opts`: Optional keyword list

  ## Returns

  - `{:ok, %{output: ..., status: 0}}` - Target built successfully
  - `{:error, reason}` - Build failed
  """
  def run_target(target, opts \\ []) when is_binary(target) do
    try do
      tools = load_tools_for_attempt(opts)

      Logger.info("BuildToolOrchestrator: Running target", target: target)

      case try_target_tools(tools, target, opts) do
        {:ok, result} ->
          Logger.info("Target build successful", target: target)
          {:ok, result}

        {:error, reason} ->
          Logger.error("Target build failed", target: target, reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Target orchestration failed", error: inspect(e))
        {:error, :target_failed}
    end
  end

  @doc """
  Clean build artifacts.

  ## Parameters

  - `project_path`: Path to project root
  - `opts`: Optional keyword list

  ## Returns

  - `:ok` - Cleaned successfully
  - `{:error, reason}` - Clean failed
  """
  def clean_build(project_path, opts \\ []) when is_binary(project_path) do
    try do
      tools = load_tools_for_attempt(opts)

      Logger.info("BuildToolOrchestrator: Cleaning build", project_path: project_path)

      case try_clean_tools(tools, project_path) do
        :ok ->
          Logger.info("Build cleaned successfully")
          :ok

        {:error, reason} ->
          Logger.error("Clean failed", reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Clean orchestration failed", error: inspect(e))
        {:error, :clean_failed}
    end
  end

  @doc """
  Get information about all configured build tools.
  """
  def get_tools_info do
    BuildToolType.load_enabled_tools()
    |> Enum.map(fn {type, priority, config} ->
      description = BuildToolType.get_description(type)

      %{
        name: type,
        enabled: true,
        priority: priority,
        description: description,
        module: config[:module],
        capabilities: get_capabilities(type)
      }
    end)
  end

  @doc """
  Get capabilities for a specific build tool.
  """
  def get_capabilities(tool_type) when is_atom(tool_type) do
    case BuildToolType.get_tool_module(tool_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) && function_exported?(module, :capabilities, 0) do
          module.capabilities()
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  # Private helpers

  defp load_tools_for_attempt(opts) do
    case Keyword.get(opts, :tools) do
      nil -> BuildToolType.load_enabled_tools()
      specific_tools -> filter_tools(specific_tools)
    end
  end

  defp filter_tools(specific_tools) when is_list(specific_tools) do
    all_tools = BuildToolType.load_enabled_tools()

    Enum.filter(all_tools, fn {type, _priority, _config} ->
      type in specific_tools
    end)
  end

  defp try_build_tools([], _project_path, _opts) do
    {:error, :no_tool_found}
  end

  defp try_build_tools([{tool_type, _priority, config} | rest], project_path, opts) do
    try do
      module = config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Trying #{tool_type} for build", project_path: project_path)

        # Check if tool is applicable
        case module.applicable?(project_path) do
          true ->
            # Tool is applicable, run build
            case module.run_build(project_path, opts) do
              {:ok, result} ->
                Logger.info("Build succeeded with #{tool_type}")
                {:ok, result}

              {:error, reason} ->
                Logger.error("#{tool_type} build failed", reason: inspect(reason))
                {:error, reason}
            end

          false ->
            # Tool not applicable, try next
            Logger.debug("#{tool_type} not applicable for project")
            try_build_tools(rest, project_path, opts)
        end
      else
        Logger.warning("Tool module not found for #{tool_type}")
        try_build_tools(rest, project_path, opts)
      end
    rescue
      e ->
        Logger.error("Build tool execution failed for #{tool_type}", error: inspect(e))
        try_build_tools(rest, project_path, opts)
    end
  end

  defp try_target_tools([], _target, _opts) do
    {:error, :no_tool_found}
  end

  defp try_target_tools([{tool_type, _priority, config} | rest], target, opts) do
    try do
      module = config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Trying #{tool_type} for target", target: target)

        case module.run_target(target, opts) do
          {:ok, result} ->
            Logger.info("Target succeeded with #{tool_type}", target: target)
            {:ok, result}

          {:error, reason} ->
            Logger.error("#{tool_type} target failed", reason: inspect(reason))
            try_target_tools(rest, target, opts)
        end
      else
        try_target_tools(rest, target, opts)
      end
    rescue
      e ->
        Logger.error("Target tool execution failed for #{tool_type}", error: inspect(e))
        try_target_tools(rest, target, opts)
    end
  end

  defp try_clean_tools([], _project_path) do
    {:error, :no_tool_found}
  end

  defp try_clean_tools([{tool_type, _priority, config} | rest], project_path) do
    try do
      module = config[:module]

      if module && Code.ensure_loaded?(module) do
        case module.clean_build(project_path) do
          :ok ->
            Logger.info("Clean succeeded with #{tool_type}")
            :ok

          {:error, reason} ->
            Logger.error("#{tool_type} clean failed", reason: inspect(reason))
            try_clean_tools(rest, project_path)
        end
      else
        try_clean_tools(rest, project_path)
      end
    rescue
      e ->
        Logger.error("Clean tool execution failed for #{tool_type}", error: inspect(e))
        try_clean_tools(rest, project_path)
    end
  end
end
