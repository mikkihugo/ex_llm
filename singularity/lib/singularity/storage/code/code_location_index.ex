defmodule Singularity.CodeLocationIndex do
  @moduledoc """
  DEPRECATED: Use Singularity.Schemas.CodeLocationIndex for schema and
  Singularity.Storage.Code.CodeLocationIndexService for service operations.

  This module now serves as a compatibility wrapper for existing code.
  """

  # Delegate schema operations to the actual schema
  defdelegate changeset(index, attrs), to: Singularity.Schemas.CodeLocationIndex

  # Delegate service operations to the actual service
  defdelegate index_codebase(path), to: Singularity.Storage.Code.CodeLocationIndexService
  defdelegate index_codebase(path, opts), to: Singularity.Storage.Code.CodeLocationIndexService
  defdelegate index_file(filepath), to: Singularity.Storage.Code.CodeLocationIndexService
  defdelegate find_pattern(pattern_keyword), to: Singularity.Storage.Code.CodeLocationIndexService
  defdelegate find_by_all_patterns(patterns), to: Singularity.Storage.Code.CodeLocationIndexService
  defdelegate find_microservices(), to: Singularity.Storage.Code.CodeLocationIndexService
  defdelegate find_microservices(type), to: Singularity.Storage.Code.CodeLocationIndexService
  defdelegate find_by_framework(framework), to: Singularity.Storage.Code.CodeLocationIndexService
  defdelegate find_nats_subscribers(subject_pattern), to: Singularity.Storage.Code.CodeLocationIndexService

  # Alias for backward compatibility
  def __schema__(:source, :code_location_index),
    do: Singularity.Schemas.CodeLocationIndex.__schema__(:source, :code_location_index)
end
