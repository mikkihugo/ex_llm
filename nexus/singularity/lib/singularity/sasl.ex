defmodule Singularity.SASL do
  @moduledoc """
  SASL (System Architecture Support Libraries) error reporting utilities.

  Provides structured error reporting using Erlang's built-in error_logger
  for proper system monitoring and crash reporting.
  """

  @doc """
  Reports a structured error to SASL with context information.

  ## Parameters
  - tag: Atom identifying the error type (e.g., :code_engine_failure, :database_error)
  - message: Human-readable error message
  - context: Keyword list of additional context (file_path, reason, etc.)
  """
  @spec error(atom(), String.t(), keyword()) :: :ok
  def error(tag, message, context \\ []) do
    report = [
      {:tag, tag},
      {:message, message},
      {:timestamp, DateTime.utc_now()},
      {:node, node()},
      {:pid, self()}
    ] ++ context

    :error_logger.error_report(report)
  end

  @doc """
  Reports a critical system failure that requires immediate attention.
  """
  @spec critical_failure(atom(), String.t(), keyword()) :: :ok
  def critical_failure(tag, message, context \\ []) do
    error(tag, "🚨 CRITICAL: #{message}", [{:severity, :critical} | context])
  end

  @doc """
  Reports a service degradation or partial failure.
  """
  @spec service_degradation(atom(), String.t(), keyword()) :: :ok
  def service_degradation(tag, message, context \\ []) do
    error(tag, "⚠️ SERVICE DEGRADATION: #{message}", [{:severity, :warning} | context])
  end

  @doc """
  Reports an infrastructure or dependency failure.
  """
  @spec infrastructure_failure(atom(), String.t(), keyword()) :: :ok
  def infrastructure_failure(tag, message, context \\ []) do
    error(tag, "🔧 INFRASTRUCTURE: #{message}", [{:severity, :error} | context])
  end

  @doc """
  Reports a data processing or analysis failure.
  """
  @spec analysis_failure(atom(), String.t(), keyword()) :: :ok
  def analysis_failure(tag, message, context \\ []) do
    error(tag, "📊 ANALYSIS: #{message}", [{:severity, :error} | context])
  end

  @doc """
  Reports a worker or task execution failure.
  """
  @spec execution_failure(atom(), String.t(), keyword()) :: :ok
  def execution_failure(tag, message, context \\ []) do
    error(tag, "⚙️ EXECUTION: #{message}", [{:severity, :error} | context])
  end

  @doc """
  Reports a database or persistence failure.
  """
  @spec database_failure(atom(), String.t(), keyword()) :: :ok
  def database_failure(tag, message, context \\ []) do
    error(tag, "💾 DATABASE: #{message}", [{:severity, :error} | context])
  end

  @doc """
  Reports an external service or API failure.
  """
  @spec external_service_failure(atom(), String.t(), keyword()) :: :ok
  def external_service_failure(tag, message, context \\ []) do
    error(tag, "🌐 EXTERNAL SERVICE: #{message}", [{:severity, :error} | context])
  end

  @doc """
  Reports a configuration or setup failure.
  """
  @spec configuration_failure(atom(), String.t(), keyword()) :: :ok
  def configuration_failure(tag, message, context \\ []) do
    error(tag, "⚙️ CONFIGURATION: #{message}", [{:severity, :error} | context])
  end
end