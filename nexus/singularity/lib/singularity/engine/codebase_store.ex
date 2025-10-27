defmodule Singularity.Engine.CodebaseStore do
  @moduledoc """
  Engine interface for accessing codebase data and services.
  Provides a clean API for other engine components to access
  analyzed codebase information.
  """

  alias Singularity.CodeStore

  @doc """
  Returns all services found across all registered codebases.
  """
  @spec all_services() :: [map()]
  def all_services do
    # Get all codebases from CodeStore
    case CodeStore.list_codebases() do
      codebases when is_list(codebases) ->
        # Extract services from each codebase's analysis
        codebases
        |> Enum.flat_map(fn codebase ->
          # Get analysis data for this codebase
          case CodeStore.get_analysis(codebase.id) do
            {:ok, analysis} ->
              # Extract services from analysis
              analysis["services"] || []

            {:error, _} ->
              # If no analysis, return empty list
              []
          end
        end)
        |> Enum.uniq_by(& &1["name"])

      _ ->
        # Fallback: return empty list
        []
    end
  end

  @doc """
  Returns services for a specific codebase.
  """
  @spec services_for_codebase(String.t()) :: [map()]
  def services_for_codebase(codebase_id) do
    case CodeStore.get_analysis(codebase_id) do
      {:ok, analysis} ->
        analysis["services"] || []

      {:error, _} ->
        []
    end
  end

  @doc """
  Finds a service by name across all codebases.
  """
  @spec find_service(String.t()) :: map() | nil
  def find_service(service_name) do
    all_services()
    |> Enum.find(&(&1.name == service_name))
  end
end
