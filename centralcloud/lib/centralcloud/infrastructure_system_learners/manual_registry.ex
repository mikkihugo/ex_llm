defmodule CentralCloud.InfrastructureSystemLearners.ManualRegistry do
  @moduledoc """
  Manual Registry Learner - Direct database queries for known infrastructure systems.

  Queries the infrastructure_systems table to retrieve systems matching the request criteria.
  Fast, reliable learner that returns systems with confidence scores.

  ## How It Works

  1. Reads the request with include categories and min_confidence filter
  2. Queries infrastructure_systems table from CentralCloud database
  3. Filters by category and confidence threshold
  4. Returns formatted systems map or :no_match if none found
  """

  require Logger
  alias CentralCloud.Infrastructure.Registry
  alias CentralCloud.InfrastructureSystemLearner

  @behaviour InfrastructureSystemLearner

  def description do
    "Direct database queries for known infrastructure systems"
  end

  @doc """
  Learn infrastructure systems by querying the manual registry.

  Returns:
  - `{:ok, systems_map}` - Systems found in registry
  - `:no_match` - No systems found matching criteria
  - `{:error, reason}` - Query failed
  """
  def learn(request) when is_map(request) do
    min_confidence = request["min_confidence"] || 0.7
    include = request["include"] || []

    try do
      # Get formatted registry from CentralCloud
      case Registry.get_formatted_registry(min_confidence: min_confidence) do
        {:ok, full_registry} ->
          # Filter by categories if specified
          response =
            if Enum.empty?(include) do
              full_registry
            else
              include_set = MapSet.new(include)

              full_registry
              |> Enum.filter(fn {category, _systems} ->
                MapSet.member?(include_set, category)
              end)
              |> Enum.into(%{})
            end

          # Return systems or :no_match if empty
          if Enum.empty?(response) do
            Logger.debug("Manual registry learner: no systems found", include: include)
            :no_match
          else
            {:ok, response}
          end

        {:error, reason} ->
          Logger.error("Manual registry learner: failed to get registry",
            error: inspect(reason)
          )
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Manual registry learner: exception occurred",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )
        {:error, e}
    end
  end

  @doc """
  Record successful learning (optional tracking for analytics).
  """
  def record_success(_request, _systems) do
    :ok
  end
end
