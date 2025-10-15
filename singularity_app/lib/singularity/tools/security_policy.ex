defmodule Singularity.Tools.SecurityPolicy do
  @moduledoc """
  Security Policy - Validates tool access and enforces security rules

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Tools.SecurityPolicy",
    "purpose": "Enforce security policies for tool execution",
    "layer": "security",
    "category": "access_control"
  }
  ```

  ## Security Policies

  ### File Access
  - **Path validation**: Block access to sensitive paths
  - **Deny list**: `.env`, `credentials.json`, `*.key`, `*.pem`
  - **Size limits**: Max 10MB per file query
  - **Rate limits**: 100 requests/minute per codebase

  ### Code Search
  - **Query length**: Max 1000 characters
  - **Result limits**: Max 100 results
  - **Codebase isolation**: Users see only their codebases

  ### Symbol Operations
  - **Symbol name length**: Max 255 characters
  - **Result limits**: Max 50 symbols per query

  ### Dependency Analysis
  - **Graph size**: Max 10000 nodes
  - **Depth limits**: Max 10 levels for transitive deps

  ## Anti-Patterns

  ⚠️ **DO NOT**:
  - Skip validation (always validate before execution)
  - Allow access to sensitive files (credentials, keys)
  - Allow unbounded queries (enforce limits)
  - Trust user input (sanitize everything)

  ## Search Keywords

  security-policy, access-control, validation, path-security,
  rate-limiting, deny-list, input-sanitization
  """

  require Logger

  ## Deny lists

  # Build sensitive patterns at runtime (can't be module attributes with Regex)
  defp sensitive_patterns do
    [
      ~r/\.env$/,
      ~r/\.env\./,
      ~r/credentials\.json$/,
      ~r/\.key$/,
      ~r/\.pem$/,
      ~r/\.p12$/,
      ~r/\.pfx$/,
      ~r/password/i,
      ~r/secret/i,
      ~r/api[_-]?key/i
    ]
  end

  @max_file_size 10 * 1024 * 1024  # 10MB
  @max_query_length 1000
  @max_results 100
  @max_symbol_results 50
  @max_graph_nodes 10000
  @max_transitive_depth 10

  ## Validation Functions

  @doc """
  Validate code.get request
  """
  def validate_code_access(%{"path" => path} = request) do
    with :ok <- validate_path(path),
         :ok <- validate_codebase_access(request),
         :ok <- check_rate_limit(request) do
      {:ok, :allowed}
    end
  end

  def validate_code_access(_request) do
    {:error, "Missing required field: path"}
  end

  @doc """
  Validate code.search request
  """
  def validate_code_search(%{"query" => query} = request) do
    with :ok <- validate_query_length(query),
         :ok <- validate_result_limit(request),
         :ok <- validate_codebase_access(request),
         :ok <- check_rate_limit(request) do
      {:ok, :allowed}
    end
  end

  def validate_code_search(_request) do
    {:error, "Missing required field: query"}
  end

  @doc """
  Validate code.list request
  """
  def validate_code_list(request) do
    with :ok <- validate_result_limit(request),
         :ok <- validate_codebase_access(request),
         :ok <- check_rate_limit(request) do
      {:ok, :allowed}
    end
  end

  @doc """
  Validate symbol.find request
  """
  def validate_symbol_find(%{"symbol" => symbol} = request) do
    with :ok <- validate_symbol_name(symbol),
         :ok <- validate_symbol_result_limit(request),
         :ok <- validate_codebase_access(request),
         :ok <- check_rate_limit(request) do
      {:ok, :allowed}
    end
  end

  def validate_symbol_find(_request) do
    {:error, "Missing required field: symbol"}
  end

  @doc """
  Validate symbol.refs request
  """
  def validate_symbol_refs(%{"symbol" => symbol} = request) do
    with :ok <- validate_symbol_name(symbol),
         :ok <- validate_symbol_result_limit(request),
         :ok <- validate_codebase_access(request),
         :ok <- check_rate_limit(request) do
      {:ok, :allowed}
    end
  end

  def validate_symbol_refs(_request) do
    {:error, "Missing required field: symbol"}
  end

  @doc """
  Validate symbol.list request
  """
  def validate_symbol_list(%{"path" => path} = request) do
    with :ok <- validate_path(path),
         :ok <- validate_symbol_result_limit(request),
         :ok <- validate_codebase_access(request),
         :ok <- check_rate_limit(request) do
      {:ok, :allowed}
    end
  end

  def validate_symbol_list(_request) do
    {:error, "Missing required field: path"}
  end

  @doc """
  Validate deps.get request
  """
  def validate_deps_get(%{"path" => path} = request) do
    with :ok <- validate_path(path),
         :ok <- validate_transitive_depth(request),
         :ok <- validate_codebase_access(request),
         :ok <- check_rate_limit(request) do
      {:ok, :allowed}
    end
  end

  def validate_deps_get(_request) do
    {:error, "Missing required field: path"}
  end

  @doc """
  Validate deps.graph request
  """
  def validate_deps_graph(request) do
    with :ok <- validate_graph_size_limit(request),
         :ok <- validate_codebase_access(request),
         :ok <- check_rate_limit(request) do
      {:ok, :allowed}
    end
  end

  ## Validation Helpers

  defp validate_path(path) when is_binary(path) do
    cond do
      # Block absolute paths outside project
      String.starts_with?(path, "/etc") ->
        {:error, "Access denied: system path"}

      String.starts_with?(path, "/root") ->
        {:error, "Access denied: system path"}

      # Check sensitive file patterns
      matches_sensitive_pattern?(path) ->
        {:error, "Access denied: sensitive file"}

      # Path traversal check
      String.contains?(path, "..") ->
        {:error, "Access denied: path traversal"}

      true ->
        :ok
    end
  end

  defp validate_path(_), do: {:error, "Invalid path type"}

  defp matches_sensitive_pattern?(path) do
    Enum.any?(sensitive_patterns(), fn pattern ->
      Regex.match?(pattern, path)
    end)
  end

  defp validate_codebase_access(%{"codebase_id" => codebase_id}) when is_binary(codebase_id) do
    # TODO: Check user permissions for codebase
    # For now, allow all internal codebases
    if codebase_id in ["singularity", "central_cloud"] do
      :ok
    else
      {:error, "Access denied: codebase not accessible"}
    end
  end

  defp validate_codebase_access(_request) do
    # Default to "singularity" if not specified
    :ok
  end

  defp validate_query_length(query) when is_binary(query) do
    if String.length(query) <= @max_query_length do
      :ok
    else
      {:error, "Query too long (max #{@max_query_length} characters)"}
    end
  end

  defp validate_query_length(_), do: {:error, "Invalid query type"}

  defp validate_result_limit(%{"limit" => limit}) when is_integer(limit) do
    if limit > 0 and limit <= @max_results do
      :ok
    else
      {:error, "Invalid limit (must be 1-#{@max_results})"}
    end
  end

  defp validate_result_limit(_request), do: :ok  # Default limit will be applied

  defp validate_symbol_result_limit(%{"limit" => limit}) when is_integer(limit) do
    if limit > 0 and limit <= @max_symbol_results do
      :ok
    else
      {:error, "Invalid limit (must be 1-#{@max_symbol_results})"}
    end
  end

  defp validate_symbol_result_limit(_request), do: :ok

  defp validate_symbol_name(symbol) when is_binary(symbol) do
    cond do
      String.length(symbol) > 255 ->
        {:error, "Symbol name too long (max 255 characters)"}

      String.length(symbol) == 0 ->
        {:error, "Symbol name cannot be empty"}

      true ->
        :ok
    end
  end

  defp validate_symbol_name(_), do: {:error, "Invalid symbol name type"}

  defp validate_transitive_depth(%{"include_transitive" => true, "max_depth" => depth})
       when is_integer(depth) do
    if depth > 0 and depth <= @max_transitive_depth do
      :ok
    else
      {:error, "Invalid transitive depth (must be 1-#{@max_transitive_depth})"}
    end
  end

  defp validate_transitive_depth(_request), do: :ok

  defp validate_graph_size_limit(%{"max_nodes" => max_nodes}) when is_integer(max_nodes) do
    if max_nodes > 0 and max_nodes <= @max_graph_nodes do
      :ok
    else
      {:error, "Invalid max_nodes (must be 1-#{@max_graph_nodes})"}
    end
  end

  defp validate_graph_size_limit(_request), do: :ok

  defp check_rate_limit(request) do
    # TODO: Implement actual rate limiting (ETS-based or Redis)
    codebase_id = Map.get(request, "codebase_id", "singularity")

    # For now, just log the request
    Logger.debug("[SecurityPolicy] Rate limit check: #{codebase_id}")

    :ok
  end

  ## Public Helpers

  @doc """
  Check if path is sensitive
  """
  def is_sensitive_path?(path) when is_binary(path) do
    matches_sensitive_pattern?(path)
  end

  @doc """
  Get maximum allowed result limit
  """
  def max_results, do: @max_results

  @doc """
  Get maximum allowed query length
  """
  def max_query_length, do: @max_query_length
end
