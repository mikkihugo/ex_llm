defmodule Singularity.Code.Quality.CodeDeduplicator do
  @moduledoc """
  Compatibility façade that forwards calls to the canonical
  `Singularity.CodeDeduplicator` module.  Several legacy callers still refer to
  this namespaced version; providing the wrapper keeps those code paths working
  while centralising all implementation in one place.
  """

  alias Singularity.CodeDeduplicator, as: Impl

  @spec find_similar(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  defdelegate find_similar(code_or_path, opts \\ []), to: Impl

  @spec index_code(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  defdelegate index_code(code, metadata), to: Impl

  @spec extract_semantic_keywords(String.t(), String.t()) :: [String.t()]
  defdelegate extract_semantic_keywords(code, language), to: Impl
end
