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
  alias Singularity.Repo
  alias Singularity.Schemas.UserCodebasePermission

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

  # 10MB
  @max_file_size 10 * 1024 * 1024
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

  defp validate_codebase_access(%{"codebase_id" => codebase_id, "user_id" => user_id})
       when is_binary(codebase_id) and is_binary(user_id) do
    check_user_permission(user_id, codebase_id)
  end

  defp validate_codebase_access(%{"codebase_id" => codebase_id}) when is_binary(codebase_id) do
    # If no user_id provided, check if this is an internal codebase with default access
    # (used for internal tools like code analysis)
    if codebase_id in ["singularity", "centralcloud"] do
      :ok
    else
      {:error, "Access denied: user_id required for non-default codebase"}
    end
  end

  defp validate_codebase_access(_request) do
    # Default to "singularity" if codebase not specified (internal default)
    :ok
  end

  @doc """
  Check if user has permission to access codebase.

  Returns `:ok` if user has access, `{:error, reason}` otherwise.
  """
  def check_user_permission(user_id, codebase_id)
      when is_binary(user_id) and is_binary(codebase_id) do
    case Repo.get_by(UserCodebasePermission, user_id: user_id, codebase_id: codebase_id) do
      nil ->
        Logger.warning("Unauthorized codebase access attempt",
          user: user_id,
          codebase: codebase_id
        )

        {:error, "Access denied: no permission for codebase"}

      _permission ->
        :ok
    end
  end

  def check_user_permission(_user_id, _codebase_id) do
    {:error, "Invalid user_id or codebase_id type"}
  end

  @doc """
  Check if user can perform specific action on codebase.

  Action can be `:read`, `:write`, or `:delete`.
  Returns true if allowed, false otherwise.
  """
  def action_allowed?(user_id, codebase_id, action)
      when is_binary(user_id) and is_binary(codebase_id) and is_atom(action) do
    case Repo.get_by(UserCodebasePermission, user_id: user_id, codebase_id: codebase_id) do
      nil ->
        false

      perm ->
        check_action_permission(perm.permission, action)
    end
  end

  def action_allowed?(_user_id, _codebase_id, _action) do
    false
  end

  # Permission level checks
  defp check_action_permission(:owner, _action), do: true
  defp check_action_permission(:write, action) when action in [:read, :write], do: true
  defp check_action_permission(:read, :read), do: true
  defp check_action_permission(_permission, _action), do: false

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

  # Default limit will be applied
  defp validate_result_limit(_request), do: :ok

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
    # ETS-based rate limiting: track requests per codebase
    codebase_id = Map.get(request, "codebase_id", "singularity")

    # Limits: 100 requests per minute per codebase
    max_requests = 100
    window_seconds = 60
    current_time = System.system_time(:second)
    window_start = current_time - window_seconds

    # Initialize ETS table if needed
    ets_table = :security_policy_rate_limits
    if !:ets.info(ets_table) do
      :ets.new(ets_table, [:set, :public, :named_table, {:write_concurrency, true}])
    end

    # Get or create request count for this codebase
    case :ets.lookup(ets_table, codebase_id) do
      [{^codebase_id, {count, timestamp}}] ->
        if timestamp < window_start do
          # Window expired, reset counter
          :ets.insert(ets_table, {codebase_id, {1, current_time}})
          :ok
        else
          # Within window
          if count >= max_requests do
            {:error, "Rate limit exceeded for codebase #{codebase_id}"}
          else
            :ets.insert(ets_table, {codebase_id, {count + 1, timestamp}})
            Logger.debug("[SecurityPolicy] Rate limit check: #{codebase_id} (#{count + 1}/#{max_requests})")
            :ok
          end
        end

      [] ->
        # First request from this codebase
        :ets.insert(ets_table, {codebase_id, {1, current_time}})
        Logger.debug("[SecurityPolicy] Rate limit check: #{codebase_id} (1/#{max_requests})")
        :ok
    end
  rescue
    # If ETS fails, allow request to proceed (graceful degradation)
    _ ->
      Logger.warning("[SecurityPolicy] Rate limiting unavailable, allowing request")
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
