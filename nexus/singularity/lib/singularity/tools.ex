defmodule Singularity.Tools do
  @moduledoc """
  Central tool execution router - delegates to domain-specific tool modules.

  This module provides unified access to all tools by routing tool names to their
  domain-specific implementations. Each tool module (Todos, FileSystem, etc.)
  implements the Singularity.Tools.Behaviour and handles its own `execute_tool/2`.

  ## Usage

      Singularity.Tools.execute_tool("create_todo", %{title: "My Task"})
      Singularity.Tools.execute_tool("fs_write_file", %{path: "file.txt", content: "..."})

  ## Tool Routing

  Tools are organized by domain:
  - **Todos** - create_todo, list_todos, search_todos, get_todo_status, get_swarm_status
  - **FileSystem** - fs_read_file, fs_write_file, fs_list_files, fs_delete_file
  - **Git** - git_commit, git_push, git_status
  - **Database** - db_query, db_migrate
  - And 30+ more tool modules

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Tools",
    "purpose": "Central tool execution router with domain delegation",
    "role": "router",
    "layer": "tools",
    "criticality": "HIGH",
    "prevents_duplicates": [
      "Tool execution routing",
      "Tool discovery and dispatch"
    ],
    "relationships": {
      "Domain modules": "Todos, FileSystem, Git, Database, etc.",
      "Agents": "Use this to execute tools",
      "Runner": "Calls this for tool execution"
    }
  }
  ```

  ### Anti-Patterns

  - ❌ **DO NOT** call domain tool modules directly - use this router
  - ❌ **DO NOT** add tool execution logic here - implement in domain modules
  - ✅ **DO** add routing rules when creating new tool domains

  ### Search Keywords

  `tools`, `execution`, `router`, `dispatch`, `domain`, `delegation`
  """

  require Logger

  @type tool_name :: String.t()
  @type args :: map()
  @type result :: {:ok, term()} | {:error, term()}

  @doc """
  Execute a tool with the given arguments.

  Routes the tool name to its domain-specific module and calls that module's
  `execute_tool/2` function.

  ## Examples

      iex> Singularity.Tools.execute_tool("create_todo", %{title: "My Task"})
      {:ok, %{success: true, todo: ...}}

      iex> Singularity.Tools.execute_tool("unknown_tool", %{})
      {:error, "Tool not found: unknown_tool"}
  """
  @spec execute_tool(tool_name(), args()) :: result()
  def execute_tool(tool_name, args) when is_binary(tool_name) and is_map(args) do
    case route_tool(tool_name) do
      {:ok, module} ->
        try do
          module.execute_tool(tool_name, args)
        rescue
          e ->
            Logger.error("Tool execution failed",
              tool: tool_name,
              error: inspect(e),
              stacktrace: __STACKTRACE__
            )

            {:error, "Tool execution failed: #{Exception.message(e)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute_tool(_tool_name, _args) do
    {:error, "Invalid arguments: tool_name must be string, args must be map"}
  end

  # ===========================
  # Tool Routing
  # ===========================

  defp route_tool(tool_name) do
    cond do
      # Todos domain
      String.starts_with?(tool_name, "todo") or tool_name in ~w[
        create_todo list_todos search_todos get_todo_status get_swarm_status
      ] ->
        {:ok, Singularity.Tools.Todos}

      # FileSystem domain
      String.starts_with?(tool_name, "fs_") ->
        {:ok, Singularity.Tools.FileSystem}

      # Git domain
      String.starts_with?(tool_name, "git_") ->
        {:ok, Singularity.Tools.Git}

      # Web search domain
      String.starts_with?(tool_name, "search_") or tool_name in ~w[web_search] ->
        {:ok, Singularity.Tools.WebSearch}

      # Code analysis domain
      String.starts_with?(tool_name, "code_") ->
        {:ok, Singularity.Tools.CodeAnalysis}

      # Planning domain
      String.starts_with?(tool_name, "planning_") ->
        {:ok, Singularity.Tools.Planning}

      # Knowledge domain
      String.starts_with?(tool_name, "knowledge_") or tool_name in ~w[package_search] ->
        {:ok, Singularity.Tools.Knowledge}

      # Database domain
      String.starts_with?(tool_name, "db_") ->
        {:ok, Singularity.Tools.Database}

      # Quality domain
      String.starts_with?(tool_name, "quality_") ->
        {:ok, Singularity.Tools.Quality}

      # Default: tool not found
      true ->
        {:error, "Tool not found: #{tool_name}"}
    end
  end
end
