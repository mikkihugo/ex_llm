defmodule ExLLM.Providers.Codex.ResponseExtractor do
  @moduledoc """
  Codex Response Extractor - Transforms WHAM task responses into structured data.

  Extracts messages, code diffs, PR metadata, and file snapshots from completed
  Codex task responses.

  ## Response Structure

  WHAM task responses contain `current_assistant_turn` with:
  - `turn_status` - Task status ("completed", "failed", etc.)
  - `output_items` - Array of result items with different types:
    - `message` - Text explanation of changes
    - `diff` or `pr` - Code changes as git diff
    - `partial_repo_snapshot` - File contents

  ## Usage

      iex> {:ok, response} = TaskClient.get_task_response("task_id")
      iex> extracted = ResponseExtractor.extract(response)
      iex> extracted.message
      "Created dark mode support with..."
      iex> extracted.code_diff
      "diff --git a/lib/..."
  """

  require Logger
  alias ExLLM.Types

  @typedoc """
  Extracted Codex response data.

  - `:status` - Task status ("completed", "failed", etc.)
  - `:message` - Text explanation of changes
  - `:code_diff` - Git diff with all changes
  - `:pr_info` - Pull request metadata (title, message, stats)
  - `:files` - File snapshots from partial_repo_snapshot
  - `:raw_response` - Original WHAM response for reference
  """
  @type extracted :: %{
          status: String.t() | nil,
          message: String.t() | nil,
          code_diff: String.t() | nil,
          pr_info: pr_info() | nil,
          files: list(file_snapshot()) | nil,
          raw_response: map()
        }

  @type pr_info :: %{
          title: String.t(),
          message: String.t(),
          files_modified: integer() | nil,
          lines_added: integer() | nil,
          lines_removed: integer() | nil
        }

  @type file_snapshot :: %{
          path: String.t(),
          content: String.t() | nil,
          language: String.t() | nil
        }

  @doc """
  Extract structured data from a WHAM task response.

  ## Arguments

  - `response` - Map from `TaskClient.get_task_response/1`

  ## Returns

  Map with extracted:
  - `:status` - Task status
  - `:message` - Text explanation
  - `:code_diff` - Git diff
  - `:pr_info` - PR metadata
  - `:files` - File contents
  - `:raw_response` - Original response

  ## Example

      iex> response = %{
      ...>   "current_assistant_turn" => %{
      ...>     "turn_status" => "completed",
      ...>     "output_items" => [
      ...>       %{"type" => "message", "content" => [%{"text" => "Added..."}]},
      ...>       %{"type" => "pr", "pr_title" => "Add feature", ...}
      ...>     ]
      ...>   }
      ...> }
      iex> extracted = extract(response)
      iex> extracted.status
      "completed"
      iex> extracted.message
      "Added..."
  """
  @spec extract(map()) :: extracted()
  def extract(response) when is_map(response) do
    assistant_turn = Map.get(response, "current_assistant_turn", %{})
    output_items = Map.get(assistant_turn, "output_items", [])
    status = Map.get(assistant_turn, "turn_status")

    %{
      status: status,
      message: extract_message(output_items),
      code_diff: extract_diff(output_items),
      pr_info: extract_pr_info(output_items),
      files: extract_file_snapshots(output_items),
      raw_response: response
    }
  end

  @doc """
  Extract just the message content from output_items.

  ## Returns

  - String with full message or nil if not found
  """
  @spec extract_message(list(map())) :: String.t() | nil
  def extract_message(output_items) when is_list(output_items) do
    Enum.find_value(output_items, fn item ->
      case item do
        %{"type" => "message", "content" => content} when is_list(content) ->
          content
          |> Enum.filter(&is_map/1)
          |> Enum.map(&Map.get(&1, "text", ""))
          |> Enum.join("\n")
          |> case do
            "" -> nil
            text -> text
          end

        _ ->
          nil
      end
    end)
  end

  @doc """
  Extract code diff from output_items.

  Checks both `diff` and `pr` type items.

  ## Returns

  - String with git diff or nil if not found
  """
  @spec extract_diff(list(map())) :: String.t() | nil
  def extract_diff(output_items) when is_list(output_items) do
    Enum.find_value(output_items, fn item ->
      case item do
        %{"type" => "diff", "diff" => diff} when is_binary(diff) ->
          diff

        %{"type" => "pr", "output_diff" => %{"diff" => diff}} when is_binary(diff) ->
          diff

        _ ->
          nil
      end
    end)
  end

  @doc """
  Extract PR metadata from output_items.

  Returns title, message, and diff statistics.

  ## Returns

  Map with PR info or nil if not found
  """
  @spec extract_pr_info(list(map())) :: pr_info() | nil
  def extract_pr_info(output_items) when is_list(output_items) do
    Enum.find_value(output_items, fn item ->
      case item do
        %{"type" => "pr"} = pr_item ->
          %{
            title: Map.get(pr_item, "pr_title"),
            message: Map.get(pr_item, "pr_message"),
            files_modified: get_in(pr_item, ["output_diff", "files_modified"]),
            lines_added: get_in(pr_item, ["output_diff", "lines_added"]),
            lines_removed: get_in(pr_item, ["output_diff", "lines_removed"])
          }

        _ ->
          nil
      end
    end)
  end

  @doc """
  Extract file snapshots from output_items.

  Returns partial repository state with file contents.

  ## Returns

  List of file maps with path and content, or nil if not found
  """
  @spec extract_file_snapshots(list(map())) :: list(file_snapshot()) | nil
  def extract_file_snapshots(output_items) when is_list(output_items) do
    Enum.find_value(output_items, fn item ->
      case item do
        %{"type" => "partial_repo_snapshot", "files" => files} when is_list(files) ->
          Enum.map(files, fn file ->
            %{
              path: Map.get(file, "path"),
              content: extract_file_content(file),
              language: detect_language(Map.get(file, "path"))
            }
          end)

        _ ->
          nil
      end
    end)
  end

  @doc """
  Extract content lines from a file snapshot.

  Handles line_range_contents arrays or full file contents.

  ## Returns

  File content as string or nil
  """
  @spec extract_file_content(map()) :: String.t() | nil
  def extract_file_content(file) when is_map(file) do
    case file do
      %{"line_range_contents" => contents} when is_list(contents) ->
        contents
        |> Enum.filter(&is_binary/1)
        |> Enum.join("\n")
        |> case do
          "" -> nil
          content -> content
        end

      %{"content" => content} when is_binary(content) ->
        content

      _ ->
        nil
    end
  end

  @doc """
  Detect language from file path.

  Simple detection based on file extension.

  ## Returns

  Language name (e.g., "elixir", "rust") or nil
  """
  @spec detect_language(String.t() | nil) :: String.t() | nil
  def detect_language(path) when is_binary(path) do
    case Path.extname(path) do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".erl" -> "erlang"
      ".rs" -> "rust"
      ".go" -> "go"
      ".py" -> "python"
      ".js" -> "javascript"
      ".ts" -> "typescript"
      ".tsx" -> "typescript"
      ".jsx" -> "javascript"
      ".java" -> "java"
      ".cs" -> "csharp"
      ".cpp" -> "cpp"
      ".c" -> "c"
      ".h" -> "c"
      ".rb" -> "ruby"
      ".php" -> "php"
      _ -> nil
    end
  end

  def detect_language(nil), do: nil

  @doc """
  Convert extracted response to ExLLM response format.

  Transforms Codex task response into standardized LLMResponse.

  ## Returns

  ExLLM LLMResponse with content, usage, and metadata
  """
  @spec to_llm_response(extracted(), Keyword.t()) :: Types.LLMResponse.t()
  def to_llm_response(extracted, opts \\ []) when is_map(extracted) do
    model = Keyword.get(opts, :model, "gpt-5-codex")

    # Construct content from message and diff
    content = build_content(extracted)

    # Estimate token usage from content (rough estimate)
    token_count = String.length(content) / 4 |> round()

    %Types.LLMResponse{
      content: content,
      model: model,
      usage: %{
        prompt_tokens: 0,
        completion_tokens: token_count,
        total_tokens: token_count
      },
      cost: 0.0,
      metadata: %{
        task_status: extracted.status,
        pr_info: extracted.pr_info,
        files: extracted.files,
        raw_response: extracted.raw_response
      }
    }
  end

  # Private helpers

  defp build_content(extracted) do
    parts = [
      extracted.message,
      extracted.code_diff
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join("\n\n---\n\n")

    case parts do
      "" -> extracted.message || "(No content available)"
      content -> content
    end
  end
end
