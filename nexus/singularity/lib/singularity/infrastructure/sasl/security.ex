defmodule Singularity.Infrastructure.Sasl.Security do
  @moduledoc """
  SASL Security module for context validation and policy enforcement.

  Provides security validation and policy enforcement for SASL authentication
  contexts, ensuring that authenticated sessions comply with security policies
  and access control requirements.

  ## Features

  - Security context validation
  - Permission-based access control
  - Session timeout management
  - Audit logging for security events
  - Integration with security validator

  ## Security Policies

  - Session timeout enforcement
  - Permission validation
  - Resource access control
  - Security event auditing
  """

  require Logger

  @type context :: map()
  @type operation :: atom()
  @type resource :: String.t()
  @type permissions :: [String.t()]

  # 1 hour in seconds
  @default_session_timeout 3600
  # 24 hours in seconds
  @max_session_timeout 86400

  @doc """
  Validate security context for ongoing operations.

  ## Parameters

  - `context` - Security context from successful authentication
  - `operation` - Operation being performed
  - `resource` - Resource being accessed
  - `required_permissions` - Required permissions for operation (optional)

  ## Returns

  - `{:ok, updated_context}` - Validation successful
  - `{:error, reason}` - Validation failed
  """
  @spec validate_context(context(), operation(), resource(), permissions()) ::
          {:ok, context()} | {:error, String.t()}
  def validate_context(context, operation, resource, required_permissions \\ []) do
    Logger.debug("Validating security context: operation=#{operation}, resource=#{resource}")

    with {:ok, context} <- validate_session_timeout(context),
         {:ok, context} <- validate_permissions(context, required_permissions),
         {:ok, context} <- validate_resource_access(context, operation, resource),
         {:ok, context} <- update_access_record(context, operation, resource) do
      Logger.debug("Security context validation successful")
      {:ok, context}
    else
      {:error, reason} ->
        Logger.warning("Security context validation failed: #{reason}")
        audit_security_event(context, operation, resource, :validation_failed, reason)
        {:error, reason}
    end
  end

  @doc """
  Check if context has required permissions.

  ## Parameters

  - `context` - Security context to check
  - `required_permissions` - List of required permissions

  ## Returns

  - `true` - All permissions are present
  - `false` - One or more permissions are missing
  """
  @spec has_permissions?(context(), permissions()) :: boolean()
  def has_permissions?(context, required_permissions) do
    user_permissions = Map.get(context, :permissions, [])
    Enum.all?(required_permissions, &(&1 in user_permissions))
  end

  @doc """
  Get user permissions from security context.

  ## Parameters

  - `context` - Security context

  ## Returns

  - List of user permissions
  """
  @spec get_user_permissions(context()) :: permissions()
  def get_user_permissions(context) do
    Map.get(context, :permissions, [])
  end

  @doc """
  Check if session is expired.

  ## Parameters

  - `context` - Security context to check
  - `current_time` - Current time (optional, defaults to now)

  ## Returns

  - `true` - Session is expired
  - `false` - Session is still valid
  """
  @spec session_expired?(context(), DateTime.t() | nil) :: boolean()
  def session_expired?(context, current_time \\ nil) do
    current_time = current_time || DateTime.utc_now()
    authenticated_at = Map.get(context, :authenticated_at)

    if authenticated_at do
      session_timeout = Map.get(context, :session_timeout, @default_session_timeout)
      expires_at = DateTime.add(authenticated_at, session_timeout, :second)

      DateTime.compare(current_time, expires_at) == :gt
    else
      # No authentication time means expired
      true
    end
  end

  @doc """
  Extend session timeout.

  ## Parameters

  - `context` - Security context to update
  - `additional_seconds` - Additional seconds to add to timeout

  ## Returns

  - Updated security context
  """
  @spec extend_session(context(), pos_integer()) :: context()
  def extend_session(context, additional_seconds) do
    current_timeout = Map.get(context, :session_timeout, @default_session_timeout)
    new_timeout = min(current_timeout + additional_seconds, @max_session_timeout)

    context
    |> Map.put(:session_timeout, new_timeout)
    |> Map.put(:last_activity, DateTime.utc_now())
    |> Map.put(:timeout_extended_at, DateTime.utc_now())
  end

  @doc """
  Revoke security context (logout).

  ## Parameters

  - `context` - Security context to revoke
  - `reason` - Reason for revocation (optional)

  ## Returns

  - Updated context marked as revoked
  """
  @spec revoke_context(context(), String.t() | nil) :: context()
  def revoke_context(context, reason \\ nil) do
    audit_security_event(context, :logout, "system", :context_revoked, reason || "User logout")

    context
    |> Map.put(:revoked, true)
    |> Map.put(:revoked_at, DateTime.utc_now())
    |> Map.put(:revocation_reason, reason)
  end

  @doc """
  Validate resource access based on security policies.

  ## Parameters

  - `context` - Security context
  - `operation` - Operation being performed
  - `resource` - Resource being accessed

  ## Returns

  - `{:ok, context}` - Access allowed
  - `{:error, reason}` - Access denied
  """
  @spec validate_resource_access(context(), operation(), resource()) ::
          {:ok, context()} | {:error, String.t()}
  def validate_resource_access(context, operation, resource) do
    # Check resource-specific access policies
    case get_resource_policy(resource) do
      {:ok, policy} ->
        if check_policy_compliance(context, operation, policy) do
          {:ok, context}
        else
          {:error, "Access denied: policy violation for resource #{resource}"}
        end

      {:error, :no_policy} ->
        # No specific policy, allow access
        {:ok, context}

      {:error, reason} ->
        {:error, "Resource policy error: #{reason}"}
    end
  end

  # ============================================================================
  # Private Helpers - Security Validation
  # ============================================================================

  defp validate_session_timeout(context) do
    if session_expired?(context) do
      {:error, "Session expired"}
    else
      {:ok, context}
    end
  end

  defp validate_permissions(context, required_permissions) do
    if has_permissions?(context, required_permissions) do
      {:ok, context}
    else
      missing_perms = required_permissions -- get_user_permissions(context)
      {:error, "Missing required permissions: #{Enum.join(missing_perms, ", ")}"}
    end
  end

  defp update_access_record(context, operation, resource) do
    # Update access record for audit trail
    access_record = %{
      operation: operation,
      resource: resource,
      timestamp: DateTime.utc_now(),
      user_id: Map.get(context, :user_id),
      session_id: Map.get(context, :session_id)
    }

    audit_security_event(context, operation, resource, :access_granted, "Successful access")

    updated_context = Map.update(context, :access_history, [access_record], &[access_record | &1])
    {:ok, updated_context}
  end

  defp get_resource_policy(resource) do
    # In a real implementation, this would query a policy database
    # For now, return mock policies based on resource patterns

    cond do
      String.starts_with?(resource, "admin/") ->
        {:ok, %{required_permissions: ["admin"], max_session_timeout: 1800}}

      String.starts_with?(resource, "system/") ->
        {:ok, %{required_permissions: ["system_access"], max_session_timeout: 3600}}

      String.starts_with?(resource, "user/") ->
        {:ok, %{required_permissions: ["user_access"], max_session_timeout: 7200}}

      true ->
        {:error, :no_policy}
    end
  end

  defp check_policy_compliance(context, operation, policy) do
    # Check if context complies with resource policy
    Logger.debug("Checking policy compliance for operation: #{operation}")
    required_perms = Map.get(policy, :required_permissions, [])
    max_timeout = Map.get(policy, :max_session_timeout, @max_session_timeout)

    has_permissions?(context, required_perms) and
      Map.get(context, :session_timeout, @default_session_timeout) <= max_timeout
  end

  defp audit_security_event(context, operation, resource, event_type, details) do
    # Audit security events for compliance and monitoring
    audit_event = %{
      timestamp: DateTime.utc_now(),
      user_id: Map.get(context, :user_id),
      session_id: Map.get(context, :session_id),
      mechanism: Map.get(context, :mechanism),
      operation: operation,
      resource: resource,
      event_type: event_type,
      details: details,
      ip_address: Map.get(context, :ip_address),
      user_agent: Map.get(context, :user_agent)
    }

    # In production, this would be sent to a security audit system
    Logger.info("Security audit: #{event_type} - #{details}", audit_event: audit_event)
  end
end
