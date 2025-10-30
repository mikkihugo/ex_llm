defmodule Singularity.Code.Analyzers.TodoDetector do
  @moduledoc """
  TODO Detector - Finds TODO, FIXME, and other incomplete implementation markers.

  Scans codebase for:
  - TODO comments (incomplete features)
  - FIXME comments (known issues)
  - HACK comments (temporary solutions)
  - XXX comments (needs attention)
  - Missing implementations (@TODO attributes)

  ## Usage

      {:ok, todos} = TodoDetector.detect_todos("/path/to/code")
      {:ok, todos} = TodoDetector.detect_todos("/path/to/code", type: :incomplete, priority: :high)
  """

  require Logger

  @todo_patterns [
    ~r/TODO[:\s]+(.*?)(?=\n|$)/i,
    ~r/FIXME[:\s]+(.*?)(?=\n|$)/i,
    ~r/HACK[:\s]+(.*?)(?=\n|$)/i,
    ~r/XXX[:\s]+(.*?)(?=\n|$)/i,
    ~r/REVIEW[:\s]+(.*?)(?=\n|$)/i,
    ~r/BUG[:\s]+(.*?)(?=\n|$)/i,
    ~r/NOTE[:\s]+(.*?)(?=\n|$)/i
  ]

  @priority_keywords %{
    high: ["urgent", "critical", "asap", "important", "blocking"],
    medium: ["soon", "needed", "required"],
    low: ["maybe", "consider", "could", "optional"]
  }

  @doc """
  Detect TODO items in codebase at given path.

  Options:
    - `type`: :all, :incomplete, :missing, :deprecated (default: :all)
    - `priority`: :all, :high, :medium, :low (default: :all)
    - `max_results`: max number of results to return (default: 100)
  """
  def detect_todos(codebase_path, opts \\ []) do
    type = Keyword.get(opts, :type, :all)
    priority = Keyword.get(opts, :priority, :all)
    max_results = Keyword.get(opts, :max_results, 100)

    try do
      todos =
        codebase_path
        |> discover_files()
        |> scan_files_for_todos()
        |> filter_by_type(type)
        |> filter_by_priority(priority)
        |> Enum.take(max_results)

      {:ok, todos}
    rescue
      error ->
        Logger.error("TodoDetector error: #{inspect(error)}")
        {:error, "TODO detection failed: #{inspect(error)}"}
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
      ex exs erl hrl rs toml rs py js ts jsx tsx java go c cpp h hpp rb rb
      php cs java kt scala clj cljs swift m mm kt gradle java xml yaml yml
      json sh bash zsh fish vim lua perl php rb go rs c cpp java cs kt
    ]

    Enum.any?(code_extensions, &String.ends_with?(path, "." <> &1))
  end

  defp scan_files_for_todos(file_paths) do
    file_paths
    |> Enum.flat_map(&scan_file_for_todos/1)
  end

  defp scan_file_for_todos(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_number} ->
          extract_todos_from_line(line, file_path, line_number)
        end)

      {:error, _reason} ->
        []
    end
  end

  defp extract_todos_from_line(line, file_path, line_number) do
    @todo_patterns
    |> Enum.flat_map(fn pattern ->
      case Regex.run(pattern, line, capture: :all_but_first) do
        [message] ->
          [
            %{
              type: extract_todo_type(line),
              message: String.trim(message),
              file: file_path,
              line: line_number,
              priority: extract_priority(message),
              created_at: DateTime.utc_now()
            }
          ]

        _ ->
          []
      end
    end)
  end

  defp extract_todo_type(line) do
    cond do
      String.match?(line, ~r/FIXME/i) -> :fixme
      String.match?(line, ~r/TODO/i) -> :incomplete
      String.match?(line, ~r/HACK/i) -> :hack
      String.match?(line, ~r/XXX/i) -> :review
      String.match?(line, ~r/BUG/i) -> :bug
      String.match?(line, ~r/REVIEW/i) -> :review
      String.match?(line, ~r/NOTE/i) -> :note
      true -> :incomplete
    end
  end

  defp extract_priority(message) do
    message_lower = String.downcase(message)

    cond do
      Enum.any?(@priority_keywords.high, &String.contains?(message_lower, &1)) ->
        :high

      Enum.any?(@priority_keywords.medium, &String.contains?(message_lower, &1)) ->
        :medium

      true ->
        :low
    end
  end

  defp filter_by_type(todos, :all), do: todos

  defp filter_by_type(todos, type) do
    Enum.filter(todos, &(&1.type == type))
  end

  defp filter_by_priority(todos, :all), do: todos

  defp filter_by_priority(todos, priority) do
    Enum.filter(todos, &(&1.priority == priority))
  end
end
