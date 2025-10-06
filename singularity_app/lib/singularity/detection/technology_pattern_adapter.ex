defmodule Singularity.TechnologyPatternAdapter do
  @moduledoc """
  Adapter for TechnologyPattern - transparently uses knowledge_artifacts

  **Migration:** technology_patterns table → knowledge_artifacts (artifact_type="technology_pattern")
  
  This adapter maintains backward compatibility while using the unified knowledge base.
  """

  alias Singularity.Knowledge.ArtifactStore
  alias Singularity.Repo
  import Ecto.Query

  @artifact_type "technology_pattern"

  @doc "Get pattern by name"
  def get_by_name(name) do
    case ArtifactStore.get(@artifact_type, normalize_id(name)) do
      {:ok, artifact} -> {:ok, to_pattern_struct(artifact)}
      {:error, _} = err -> err
    end
  end

  @doc "Get all patterns for a language"
  def get_by_language(language) do
    {:ok, results} = ArtifactStore.search("", 
      artifact_type: @artifact_type,
      language: language,
      top_k: 1000
    )
    
    Enum.map(results, &to_pattern_struct/1)
  end

  @doc "Get all patterns"
  def all do
    query = from ka in "knowledge_artifacts",
      where: ka.artifact_type == ^@artifact_type,
      select: ka
      
    Repo.all(query)
    |> Enum.map(&to_pattern_struct/1)
  end

  @doc "Store/update pattern"
  def upsert(pattern_attrs) do
    artifact = %{
      artifact_type: @artifact_type,
      artifact_id: normalize_id(pattern_attrs[:name] || pattern_attrs["name"]),
      language: pattern_attrs[:language] || pattern_attrs["language"] || "unknown",
      content: pattern_attrs,
      metadata: %{source: "elixir_code"}
    }
    
    ArtifactStore.store(artifact)
  end

  @doc "Record detection (tracks usage)"
  def record_detection(name, success \\ true) do
    ArtifactStore.record_usage(
      @artifact_type,
      normalize_id(name),
      success: success
    )
  end

  @doc "Search patterns"
  def search(query, opts \\ []) do
    {:ok, results} = ArtifactStore.search(query, 
      Keyword.merge([artifact_type: @artifact_type], opts)
    )
    
    Enum.map(results, &to_pattern_struct/1)
  end

  # Convert knowledge_artifact to pattern-like struct
  defp to_pattern_struct(artifact) do
    content = if is_binary(artifact.content), do: Jason.decode!(artifact.content), else: artifact.content
    
    %{
      id: artifact.id,
      name: content["name"],
      type: content["type"],
      language: artifact.language,
      detector_signatures: content["detector_signatures"],
      file_patterns: content["file_patterns"],
      config_files: content["config_files"],
      build_command: content["build_command"],
      dev_command: content["dev_command"],
      test_command: content["test_command"],
      install_command: content["install_command"],
      detection_count: artifact.usage_count || 0,
      success_rate: artifact.success_rate || 0.0,
      inserted_at: artifact.inserted_at,
      updated_at: artifact.updated_at
    }
  end

  defp normalize_id(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
  end
  defp normalize_id(nil), do: "unknown"
end
