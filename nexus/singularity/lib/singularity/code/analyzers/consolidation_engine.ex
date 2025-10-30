defmodule Singularity.Code.Analyzers.ConsolidationEngine do
  @moduledoc """
  Consolidation Engine - Identifies code consolidation opportunities.

  Detects opportunities to:
  - Merge duplicate code sections
  - Extract common functionality
  - Consolidate similar modules
  - Reduce code redundancy

  ## Usage

      {:ok, opportunities} = ConsolidationEngine.find_consolidation_opportunities("/path")
      {:ok, opportunities} = ConsolidationEngine.find_consolidation_opportunities(
        "/path",
        consolidation_type: :duplicates,
        similarity_threshold: 0.8
      )
  """

  require Logger

  @doc """
  Find code consolidation opportunities in codebase.

  Options:
    - `consolidation_type`: :all, :duplicates, :similar, :dead (default: :all)
    - `similarity_threshold`: 0.0-1.0 minimum similarity for grouping (default: 0.8)
    - `min_lines`: minimum lines for consolidation suggestion (default: 10)
  """
  def find_consolidation_opportunities(codebase_path, opts \\ []) do
    consolidation_type = Keyword.get(opts, :consolidation_type, :all)
    similarity_threshold = Keyword.get(opts, :similarity_threshold, 0.8)
    min_lines = Keyword.get(opts, :min_lines, 10)

    try do
      opportunities =
        codebase_path
        |> discover_files()
        |> analyze_consolidation(
          consolidation_type,
          similarity_threshold,
          min_lines
        )

      {:ok,
       %{
         codebase_path: codebase_path,
         consolidation_type: consolidation_type,
         similarity_threshold: similarity_threshold,
         opportunities: opportunities,
         count: length(opportunities),
         total_lines_saveable: sum_saveable_lines(opportunities),
         analyzed_at: DateTime.utc_now()
       }}
    rescue
      error ->
        Logger.error("ConsolidationEngine error: #{inspect(error)}")
        {:error, "Consolidation analysis failed: #{inspect(error)}"}
    end
  end

  # Private helpers ===================================================

  defp discover_files(path) do
    cond do
      File.regular?(path) ->
        [path]

      File.dir?(path) ->
        path
        |> Path.join("**/*")
        |> Path.wildcard(match_dot: true)
        |> Enum.filter(&File.regular?/1)
        |> Enum.filter(&is_code_file/1)

      true ->
        []
    end
  end

  defp is_code_file(path) do
    # Common code file extensions
    code_extensions = ~w[
      ex exs erl hrl rs toml rs py js ts jsx tsx java go c cpp h hpp rb
      php cs java kt scala clj cljs swift m mm kt gradle java xml yaml yml
    ]

    Enum.any?(code_extensions, &String.ends_with?(path, "." <> &1))
  end

  defp analyze_consolidation(file_paths, consolidation_type, similarity_threshold, min_lines) do
    # Load all files with metadata
    files_data =
      file_paths
      |> Enum.map(&load_file_data/1)
      |> Enum.reject(&is_nil/1)

    # Find consolidation opportunities based on type
    case consolidation_type do
      :all ->
        find_all_opportunities(files_data, similarity_threshold, min_lines)

      :duplicates ->
        find_duplicate_blocks(files_data, min_lines)

      :similar ->
        find_similar_code(files_data, similarity_threshold, min_lines)

      :dead ->
        find_dead_code(files_data)

      _ ->
        find_all_opportunities(files_data, similarity_threshold, min_lines)
    end
  end

  defp load_file_data(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        %{
          path: file_path,
          content: content,
          lines: lines,
          line_count: length(lines),
          hash: hash_content(content)
        }

      {:error, _reason} ->
        nil
    end
  end

  defp hash_content(content) do
    :crypto.hash(:sha256, content)
    |> Base.encode16(case: :lower)
  end

  defp find_all_opportunities(files_data, similarity_threshold, min_lines) do
    [
      find_duplicate_blocks(files_data, min_lines),
      find_similar_code(files_data, similarity_threshold, min_lines)
    ]
    |> List.flatten()
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.potential_savings, :desc)
  end

  defp find_duplicate_blocks(files_data, min_lines) do
    # Simple duplication detection: same blocks of lines in different files
    all_blocks =
      files_data
      |> Enum.flat_map(&extract_blocks(&1, min_lines))

    all_blocks
    |> Enum.group_by(& &1.hash)
    |> Enum.filter(fn {_hash, blocks} -> length(blocks) > 1 end)
    |> Enum.map(fn {_hash, blocks} ->
      %{
        id: "dup_#{:crypto.strong_rand_bytes(4) |> Base.encode16()}",
        type: :duplicate,
        description: "Exact duplicate code found in #{length(blocks)} locations",
        locations: blocks,
        lines: blocks |> hd() |> Map.get(:lines),
        potential_savings: (blocks |> hd() |> Map.get(:lines) |> length()) * (length(blocks) - 1),
        difficulty: :low,
        recommendation: "Extract to shared function or module"
      }
    end)
  end

  defp find_similar_code(files_data, similarity_threshold, min_lines) do
    # Placeholder for similarity-based consolidation
    # Would use string similarity metrics to find similar blocks
    []
  end

  defp find_dead_code(files_data) do
    # Placeholder for dead code detection
    # Would identify unused functions/modules
    []
  end

  defp extract_blocks(%{path: path, lines: lines}, min_lines) do
    lines
    |> Enum.chunk_every(min_lines, 1)
    |> Enum.filter(&(length(&1) >= min_lines))
    |> Enum.map(fn block ->
      content = Enum.join(block, "\n")

      %{
        file: path,
        lines: block,
        hash: hash_content(content),
        line_count: length(block)
      }
    end)
  end

  defp sum_saveable_lines(opportunities) do
    opportunities
    |> Enum.map(&Map.get(&1, :potential_savings, 0))
    |> Enum.sum()
  end
end
