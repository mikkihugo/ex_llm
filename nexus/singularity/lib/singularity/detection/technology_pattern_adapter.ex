defmodule Singularity.TechnologyPatternAdapter do
  @moduledoc """
  Adapter for TechnologyPattern - transparently uses knowledge_artifacts

  **Migration:** technology_patterns table → knowledge_artifacts (artifact_type="technology_pattern")

  This adapter maintains backward compatibility while using the unified knowledge base.
  """

  alias Singularity.Knowledge.ArtifactStore
  alias Singularity.Detection.ApprovedPatternStore
  alias Singularity.Schemas.ApprovedPattern
  alias Singularity.Repo
  import Ecto.Query

  @artifact_type "technology_pattern"

  @doc "Get pattern by name"
  def get_by_name(name, opts \\ []) do
    case ArtifactStore.get(@artifact_type, normalize_id(name)) do
      {:ok, artifact} ->
        {:ok, to_pattern_struct(artifact)}

      {:error, _reason} ->
        ecosystem = Keyword.get(opts, :ecosystem) || Keyword.get(opts, :language)

        case ApprovedPatternStore.get_by_name(name, ecosystem: ecosystem) do
          {:ok, pattern} ->
            {:ok, to_pattern_struct(pattern)}

          {:error, _} = err ->
            err
        end
    end
  end

  @doc "Get all patterns for a language"
  def get_by_language(language) do
    artifacts =
      case ArtifactStore.search("",
             artifact_type: @artifact_type,
             language: language,
             top_k: 1000
           ) do
        {:ok, results} -> Enum.map(results, &to_pattern_struct/1)
        {:error, _} -> []
      end

    replicated =
      ApprovedPatternStore.list_by_ecosystem(language)
      |> Enum.reject(fn pattern ->
        Enum.any?(artifacts, &(Map.get(&1, :name) == pattern.name))
      end)
      |> Enum.map(&to_pattern_struct/1)

    artifacts ++ replicated
  end

  @doc "Get all patterns"
  def all do
    knowledge =
      "knowledge_artifacts"
      |> from(as: :ka)
      |> where([ka: ka], ka.artifact_type == ^@artifact_type)
      |> select([ka: ka], ka)
      |> Repo.all()
      |> Enum.map(&to_pattern_struct/1)

    replicated =
      ApprovedPatternStore.all()
      |> Enum.reject(fn pattern ->
        Enum.any?(knowledge, &(Map.get(&1, :name) == pattern.name))
      end)
      |> Enum.map(&to_pattern_struct/1)

    knowledge ++ replicated
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
    {language, opts} = Keyword.pop(opts, :language)
    {ecosystem, opts} = Keyword.pop(opts, :ecosystem, language)

    knowledge =
      case ArtifactStore.search(
             query,
             Keyword.merge([artifact_type: @artifact_type], opts)
           ) do
        {:ok, results} -> Enum.map(results, &to_pattern_struct/1)
        {:error, _} -> []
      end

    replicated =
      ApprovedPatternStore.search(query,
        top_k: Keyword.get(opts, :top_k, 25),
        ecosystem: ecosystem
      )
      |> Enum.reject(fn pattern ->
        Enum.any?(knowledge, &(Map.get(&1, :name) == pattern.name))
      end)
      |> Enum.map(&to_pattern_struct/1)

    knowledge ++ replicated
  end

  # Convert knowledge_artifact to pattern-like struct
  defp to_pattern_struct(%ApprovedPattern{} = pattern) do
    examples = normalize_examples(pattern.examples)

    detector_signatures =
      Map.get(examples, "detector_signatures") ||
        Map.get(examples, :detector_signatures) ||
        %{}

    file_patterns =
      Map.get(examples, "file_patterns") ||
        Map.get(examples, :file_patterns) ||
        []

    config_files =
      Map.get(examples, "config_files") ||
        Map.get(examples, :config_files) ||
        []

    %{
      id: pattern.id,
      name: pattern.name,
      type: Map.get(examples, "type") || Map.get(examples, :type) || "approved_pattern",
      language: pattern.ecosystem,
      detector_signatures: detector_signatures,
      file_patterns: file_patterns,
      config_files: config_files,
      build_command: Map.get(examples, "build_command") || Map.get(examples, :build_command),
      dev_command: Map.get(examples, "dev_command") || Map.get(examples, :dev_command),
      test_command: Map.get(examples, "test_command") || Map.get(examples, :test_command),
      install_command:
        Map.get(examples, "install_command") || Map.get(examples, :install_command),
      detection_count: pattern.frequency || pattern.instances_count || 0,
      success_rate: pattern.confidence || 0.0,
      inserted_at: pattern.inserted_at,
      updated_at: pattern.updated_at
    }
  end

  defp to_pattern_struct(artifact) do
    content =
      if is_binary(artifact.content), do: Jason.decode!(artifact.content), else: artifact.content

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

  defp normalize_examples(nil), do: %{}

  defp normalize_examples(examples) when is_map(examples), do: examples

  defp normalize_examples(examples) when is_list(examples) do
    %{"examples" => examples}
  end

  defp normalize_examples(_examples), do: %{}

  defp normalize_id(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
  end

  defp normalize_id(nil), do: "unknown"
end
