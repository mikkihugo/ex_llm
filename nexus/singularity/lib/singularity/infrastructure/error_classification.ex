defmodule Singularity.Infrastructure.ErrorClassification do
  @moduledoc """
  Structured error classification borrowed from the legacy branch and adapted for the PGFlow
  architecture.

  The intent is to provide a consistent vocabulary (`:validation_error`, `:external_error`, etc.)
  plus telemetry-friendly error responses that downstream tooling can consume.
  """

  require Logger

  @type error_type ::
          :validation_error
          | :not_found_error
          | :system_error
          | :external_error
          | :configuration_error
          | :authentication_error
          | :authorization_error
          | :internal_error
          | :timeout_error
          | :conflict_error

  @type error_response :: %{
          error: error_type(),
          message: String.t(),
          operation: atom(),
          context: map(),
          correlation_id: String.t(),
          timestamp: DateTime.t(),
          recovery_action: String.t() | nil
        }

  @doc """
  Classify an exception into one of the known error buckets.
  """
  @spec classify_exception(Exception.t()) :: error_type()
  def classify_exception(%ArgumentError{}), do: :validation_error
  def classify_exception(%KeyError{}), do: :validation_error
  def classify_exception(%FunctionClauseError{}), do: :validation_error
  def classify_exception(%File.Error{}), do: :system_error
  def classify_exception(%DBConnection.ConnectionError{}), do: :external_error
  def classify_exception(%Postgrex.Error{}), do: :external_error
  def classify_exception(%Mint.TransportError{}), do: :external_error
  def classify_exception(%Ecto.ConstraintError{}), do: :conflict_error

  def classify_exception(error) do
    if Exception.message(error) =~ ~r/timeout|Timeout/i do
      :timeout_error
    else
      :internal_error
    end
  end

  @doc """
  Build a structured error response payload and emit telemetry/logging side effects.
  """
  @spec error_response(error_type(), atom(), map(), Exception.t() | nil) ::
          {:error, error_response()}
  def error_response(error_type, operation, context \\ %{}, exception \\ nil) do
    correlation_id = Map.get(context, :correlation_id, generate_correlation_id())
    message = error_message(error_type, exception)
    recovery = recovery_action(error_type)

    payload = %{
      error: error_type,
      message: message,
      operation: operation,
      context: Map.put(context, :exception_class, exception_class(exception)),
      correlation_id: correlation_id,
      timestamp: DateTime.utc_now(),
      recovery_action: recovery
    }

    log_error(payload)
    emit_telemetry(payload)

    {:error, payload}
  end

  @doc """
  Log an error with structured metadata for observability.
  """
  @spec log_error(error_response()) :: :ok
  def log_error(payload) do
    Logger.error(
      "Operation #{payload.operation} failed with #{payload.error}",
      correlation_id: payload.correlation_id,
      error_type: payload.error,
      message: payload.message,
      context: inspect(payload.context)
    )

    :ok
  end

  @doc """
  Emit a telemetry event for the error.
  """
  @spec emit_telemetry(error_response()) :: :ok
  def emit_telemetry(payload) do
    :telemetry.execute(
      [:singularity, :error, payload.error],
      %{count: 1},
      Map.take(payload, [:operation, :context, :correlation_id, :recovery_action])
    )

    :ok
  end

  defp recovery_action(:validation_error), do: "Verify input parameters and retry."
  defp recovery_action(:not_found_error), do: "Confirm the resource identifier is valid."
  defp recovery_action(:system_error), do: "Check filesystem permissions and system resources."

  defp recovery_action(:external_error),
    do: "Validate dependent services (PostgreSQL, HTTP APIs)."

  defp recovery_action(:configuration_error), do: "Review configuration settings and credentials."
  defp recovery_action(:authentication_error), do: "Refresh authentication credentials."
  defp recovery_action(:authorization_error), do: "Ensure the caller has required permissions."
  defp recovery_action(:timeout_error), do: "Increase timeout or reduce workload size."
  defp recovery_action(:conflict_error), do: "Retry or resolve concurrent modifications."
  defp recovery_action(:internal_error), do: nil

  defp error_message(_type, nil), do: "An error occurred."
  defp error_message(_type, exception), do: Exception.message(exception)

  defp exception_class(nil), do: nil
  defp exception_class(%{__struct__: struct}), do: inspect(struct)

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end
end
