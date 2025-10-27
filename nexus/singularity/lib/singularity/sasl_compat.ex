defmodule SASL do
  @moduledoc """
  Compatibility shim so code that calls `SASL.*` (short name) works
  by delegating to `Singularity.SASL`.
  """

  def execution_failure(tag, message, context \\ []) do
    Singularity.SASL.execution_failure(tag, message, context)
  end

  def critical_failure(tag, message, context \\ []) do
    Singularity.SASL.critical_failure(tag, message, context)
  end

  def analysis_failure(tag, message, context \\ []) do
    Singularity.SASL.analysis_failure(tag, message, context)
  end

  def infrastructure_failure(tag, message, context \\ []) do
    Singularity.SASL.infrastructure_failure(tag, message, context)
  end

  def database_failure(tag, message, context \\ []) do
    Singularity.SASL.database_failure(tag, message, context)
  end

  def external_service_failure(tag, message, context \\ []) do
    Singularity.SASL.external_service_failure(tag, message, context)
  end

  def service_degradation(tag, message, context \\ []) do
    Singularity.SASL.service_degradation(tag, message, context)
  end
end
