defmodule Singularity.Analysis.Extractors.PatternExtractor do
  @moduledoc """
  Pattern Extractor - Extracts code patterns and structures.

  Wraps CodePatternExtractor into unified ExtractorType behavior.
  """

  @behaviour Singularity.Analysis.ExtractorType
  require Logger
  alias Singularity.CodePatternExtractor

  @impl true
  def extractor_type, do: :pattern

  @impl true
  def description, do: "Extract code patterns and structures"

  @impl true
  def capabilities do
    ["pattern_extraction", "structure_analysis", "similarity_detection"]
  end

  @impl true
  def extract(input, opts \\ []) when is_binary(input) do
    try do
      case CodePatternExtractor.extract(input, opts) do
        {:ok, patterns} -> {:ok, %{patterns: patterns}}
        {:error, reason} -> {:error, reason}
      end
    rescue
      e ->
        Logger.error("Pattern extraction failed", error: inspect(e))
        {:error, :extraction_failed}
    end
  end

  @impl true
  def learn_from_extraction(result) do
    case result do
      %{patterns: patterns, success: true} when is_list(patterns) ->
        Logger.info("Pattern extraction was successful, #{length(patterns)} patterns extracted")
        :ok

      _ ->
        :ok
    end
  end
end
