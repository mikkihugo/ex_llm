defmodule SingularityLLM.Providers.Jules.ResponseExtractor do
  @moduledoc """
  Jules Response Extractor - Transforms session responses into structured data.

  Extracts code changes, activities, and metadata from completed Jules sessions.

  ## Response Structure

  Jules sessions contain:
  - `state` - Session state ("initializing", "planning", "executing", "done", "failed")
  - `activities` - List of individual code changes/actions
  - `title` - Session title/summary
  - `initialMessage` - Original prompt

  ## Activity Types

  - `codeChange` - Code modification with diff
  - `codeCreation` - New file created
  - `fileModification` - File changed
  - `explanation` - Text explanation

  ## Usage

      iex> {:ok, session} = TaskClient.get_session(session_id)
      iex> {:ok, activities} = TaskClient.get_activities(session_id)
      iex> extracted = ResponseExtractor.extract(session, activities)
      iex> extracted.code_changes
      [%{file: "file.py", diff: "..."}]
  """

  require Logger
  alias SingularityLLM.Types

  @typedoc """
  Extracted Jules response data.

  - `:state` - Session state
  - `:title` - Session summary
  - `:code_changes` - List of code modifications
  - `:activities` - Original activities list
  - `:raw_session` - Original session object
  """
  @type extracted :: %{
          state: String.t() | nil,
          title: String.t() | nil,
          code_changes: list(code_change()) | nil,
          activities: list(map()) | nil,
          raw_session: map()
        }

  @type code_change :: %{
          file: String.t(),
          type: String.t(),
          diff: String.t() | nil,
          content: String.t() | nil
        }

  @doc """
  Extract structured data from a Jules session and activities.

  ## Arguments

  - `session` - Map from `TaskClient.get_session/1`
  - `activities` - List from `TaskClient.get_activities/1`

  ## Returns

  Map with extracted:
  - `:state` - Session state
  - `:title` - Session title
  - `:code_changes` - List of code modifications
  - `:activities` - Original activities
  - `:raw_session` - Original session

  ## Example

      iex> {:ok, session} = get_session(session_id)
      iex> {:ok, activities} = get_activities(session_id)
      iex> extracted = extract(session, activities)
      iex> extracted.state
      "done"
      iex> Enum.map(extracted.code_changes, & &1.file)
      ["app.py", "utils.py"]
  """
  @spec extract(map(), list(map())) :: extracted()
  def extract(session, activities) when is_map(session) and is_list(activities) do
    %{
      state: Map.get(session, "state"),
      title: Map.get(session, "title"),
      code_changes: extract_code_changes(activities),
      activities: activities,
      raw_session: session
    }
  end

  @doc """
  Extract code changes from activities list.

  ## Returns

  - List of code_change maps with file, type, diff/content
  """
  @spec extract_code_changes(list(map())) :: list(code_change()) | nil
  def extract_code_changes(activities) when is_list(activities) do
    activities
    |> Enum.filter(&is_code_activity?/1)
    |> Enum.map(&parse_activity/1)
    |> case do
      [] -> nil
      changes -> changes
    end
  end

  @doc """
  Extract just the code changes as a combined diff.

  ## Returns

  - Single string with all diffs concatenated
  """
  @spec extract_combined_diff(list(code_change())) :: String.t() | nil
  def extract_combined_diff(code_changes) when is_list(code_changes) do
    diffs =
      code_changes
      |> Enum.filter(&is_binary(&1.diff))
      |> Enum.map(& &1.diff)

    case diffs do
      [] -> nil
      diffs -> Enum.join(diffs, "\n\n---\n\n")
    end
  end

  @doc """
  Extract just the content of new files.

  ## Returns

  - Map of filepath => content
  """
  @spec extract_new_files(list(code_change())) :: map() | nil
  def extract_new_files(code_changes) when is_list(code_changes) do
    files =
      code_changes
      |> Enum.filter(&(&1.type == "codeCreation"))
      |> Enum.map(&{&1.file, &1.content})
      |> Enum.into(%{})

    case files do
      empty when map_size(empty) == 0 -> nil
      files -> files
    end
  end

  @doc """
  Convert extracted response to SingularityLLM response format.

  Transforms Jules session response into standardized LLMResponse.

  ## Returns

  SingularityLLM LLMResponse with content, usage, and metadata
  """
  @spec to_llm_response(extracted(), Keyword.t()) :: Types.LLMResponse.t()
  def to_llm_response(extracted, opts \\ []) when is_map(extracted) do
    model = Keyword.get(opts, :model, "google-jules")

    # Construct content from code changes
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
        session_state: extracted.state,
        session_title: extracted.title,
        code_changes: extracted.code_changes,
        raw_session: extracted.raw_session
      }
    }
  end

  # Private helpers

  defp is_code_activity?(activity) when is_map(activity) do
    type = Map.get(activity, "type")
    type in ["codeChange", "codeCreation", "fileModification"]
  end

  defp is_code_activity?(_), do: false

  defp parse_activity(activity) when is_map(activity) do
    type = Map.get(activity, "type", "unknown")
    file = Map.get(activity, "file") || Map.get(activity, "filePath")

    diff = extract_diff_from_activity(activity)
    content = extract_content_from_activity(activity)

    %{
      file: file,
      type: type,
      diff: diff,
      content: content
    }
  end

  defp extract_diff_from_activity(activity) when is_map(activity) do
    case activity do
      %{"diff" => diff} when is_binary(diff) -> diff
      %{"outputDiff" => %{"diff" => diff}} -> diff
      _ -> nil
    end
  end

  defp extract_content_from_activity(activity) when is_map(activity) do
    case activity do
      %{"content" => content} when is_binary(content) -> content
      %{"fileContents" => content} when is_binary(content) -> content
      %{"newContent" => content} when is_binary(content) -> content
      _ -> nil
    end
  end

  defp build_content(extracted) do
    parts = [
      if(extracted.title, do: "# #{extracted.title}"),
      if(extracted.state, do: "**Status:** #{extracted.state}"),
      extract_combined_diff(extracted.code_changes || [])
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join("\n\n---\n\n")

    case parts do
      "" -> extracted.state || "(No content available)"
      content -> content
    end
  end
end
