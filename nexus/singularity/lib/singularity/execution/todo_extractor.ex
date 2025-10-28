defmodule Singularity.Execution.TodoExtractor do
  @moduledoc """
  TODO Comment Extractor - Centralized TODO extraction from code files

  **PURPOSE**: Extract ALL code smell comments from code files and convert them
  into actionable todo items in the database.

  **CODE SMELL DETECTION**: Captures all actionable markers including TODOs,
  FIXMEs, stubs, hacks, debug code, dead code, unused code, and hidden notes.

  ## Module Identity

  ```json
  {
    "module_name": "Singularity.Execution.TodoExtractor",
    "purpose": "Extract TODO comments from code and create database todos",
    "type": "Pure function module (no GenServer)",
    "operates_on": "Code files (.ex, .rs, .ts, .js, .py, .go, etc.)",
    "output": "Todo records in database",
    "dependencies": ["AstQualityAnalyzer", "TodoStore"]
  }
  ```

  ## Call Graph (YAML)

  ```yaml
  TodoExtractor:
    calls:
      - AstQualityAnalyzer.find_todo_and_fixme_comments/1  # Extract comments
      - TodoStore.create/1  # Create todo records
      - extract_todo_text/1  # Clean comment text
      - determine_priority/1  # Set priority based on comment type
    called_by:
      - CodeFileWatcher.extract_todos_from_file/1  # Real-time extraction
      - TodoExtractor.extract_from_codebase/1  # Batch extraction
  ```

  ## Anti-Patterns

  **DO NOT create these duplicates:**
  - ❌ `CommentExtractor` - This IS the comment extractor
  - ❌ `TodoCommentParser` - Same purpose
  - ❌ `CodeCommentAnalyzer` - Subset of this module

  ## Usage

      # Extract actionable TODOs from a single file
      {:ok, todos} = TodoExtractor.extract_from_file("lib/my_module.ex")
      # => Only extracts # TODO: and # FIXME: comments with meaningful content
      # => Filters out # STUB:, # NOTE:, # DEBUG:, # HACK:, etc.

      # Extract TODOs from file after database update
      {:ok, todos} = TodoExtractor.extract_after_file_update("lib/my_module.ex")

  ## What Gets Extracted

  **✅ EXTRACTED (All Code Smells):**
  - `# TODO: Implement user authentication`
  - `# FIXME: Handle null pointer exception`
  - `# NOTE: This needs refactoring for performance`
  - `# STUB: Placeholder for future implementation`
  - `# HACK: Quick workaround for testing`
  - `# DEBUG: Temporary logging statement`
  - `# DEAD: This code should be removed`
  - `# UNUSED: Legacy function no longer needed`
  - `# DEPRECATED: Use new API instead`
  - `# REMOVE: Old configuration file`
  - `# WORKAROUND: Temporary fix for edge case`
  - `# QUICKFIX: Handle null case`
  - `# TEMP: Temporary code for testing`
  - `# PLACEHOLDER: Will implement later`

  **🔗 UUID TRACKING:**
  - `# TODO: Fix memory leak [uuid: 123e4567-e89b-12d3-a456-426614174000]`
  - `# FIXME: Handle edge case [uuid: 987fcdeb-51a2-43d1-9f12-3456789abcde]`
  - Auto-generates UUIDs for new todos
  - Updates existing todos when content changes
  - Prevents duplicate todos from same comment

  **❌ FILTERED OUT (Pure Documentation):**
  - `# INFO: This is just information`
  - `# DOC: This is documentation`
  - `# COMMENT: This is an explanation`
  - `# TEST: This is test code`
  - `# EXAMPLE: This is example code`
  - `# SAMPLE: This is sample code`
  """

  alias Singularity.Execution.TodoStore
  alias Singularity.CodeQuality.AstQualityAnalyzer

  require Logger
  require Ecto.Query

  # Production-ready comment patterns - only extract actionable items
  @default_patterns [
    {"elixir", "# TODO: $$$", "TODO comment - incomplete work"},
    {"elixir", "# FIXME: $$$", "FIXME comment - needs fixing"},
    {"rust", "// TODO: $$$", "TODO comment - incomplete work"},
    {"rust", "// FIXME: $$$", "FIXME comment - needs fixing"},
    {"javascript", "// TODO: $$$", "TODO comment - incomplete work"},
    {"javascript", "// FIXME: $$$", "FIXME comment - needs fixing"},
    {"python", "# TODO: $$$", "TODO comment - incomplete work"},
    {"python", "# FIXME: $$$", "FIXME comment - needs fixing"}
  ]

  # Patterns to EXCLUDE (only pure documentation, not actionable code smells)
  @excluded_patterns [
    # Pure documentation (not actionable)
    {"elixir", "# NOTE: $$$", "NOTE comment - pure documentation"},
    {"elixir", "# INFO: $$$", "INFO comment - pure information"},
    {"elixir", "# DOC: $$$", "DOC comment - pure documentation"},
    {"elixir", "# COMMENT: $$$", "COMMENT comment - pure explanation"},

    # Test/example code (not actionable in production)
    {"elixir", "# TEST: $$$", "TEST comment - test code"},
    {"elixir", "# EXAMPLE: $$$", "EXAMPLE comment - example code"},
    {"elixir", "# SAMPLE: $$$", "SAMPLE comment - sample code"},

    # Rust equivalents
    {"rust", "// NOTE: $$$", "NOTE comment - pure documentation"},
    {"rust", "// INFO: $$$", "INFO comment - pure information"},
    {"rust", "// DOC: $$$", "DOC comment - pure documentation"},
    {"rust", "// COMMENT: $$$", "COMMENT comment - pure explanation"},
    {"rust", "// TEST: $$$", "TEST comment - test code"},
    {"rust", "// EXAMPLE: $$$", "EXAMPLE comment - example code"},
    {"rust", "// SAMPLE: $$$", "SAMPLE comment - sample code"},

    # JavaScript equivalents
    {"javascript", "// NOTE: $$$", "NOTE comment - pure documentation"},
    {"javascript", "// INFO: $$$", "INFO comment - pure information"},
    {"javascript", "// DOC: $$$", "DOC comment - pure documentation"},
    {"javascript", "// COMMENT: $$$", "COMMENT comment - pure explanation"},
    {"javascript", "// TEST: $$$", "TEST comment - test code"},
    {"javascript", "// EXAMPLE: $$$", "EXAMPLE comment - example code"},
    {"javascript", "// SAMPLE: $$$", "SAMPLE comment - sample code"},

    # Python equivalents
    {"python", "# NOTE: $$$", "NOTE comment - pure documentation"},
    {"python", "# INFO: $$$", "INFO comment - pure information"},
    {"python", "# DOC: $$$", "DOC comment - pure documentation"},
    {"python", "# COMMENT: $$$", "COMMENT comment - pure explanation"},
    {"python", "# TEST: $$$", "TEST comment - test code"},
    {"python", "# EXAMPLE: $$$", "EXAMPLE comment - example code"},
    {"python", "# SAMPLE: $$$", "SAMPLE comment - sample code"}
  ]

  # Priority mapping for comment types
  @priority_map %{
    # Critical - needs fixing
    "FIXME" => 1,
    # High - incomplete work
    "TODO" => 2,
    # High - placeholder code
    "STUB" => 3,
    # Medium - temporary solution
    "HACK" => 4,
    # Medium - debugging code
    "DEBUG" => 5,
    # Medium - dead code
    "DEAD" => 6,
    # Medium - unused code
    "UNUSED" => 7,
    # Medium - deprecated code
    "DEPRECATED" => 8,
    # Medium - code to remove
    "REMOVE" => 9,
    # Low - temporary fix
    "WORKAROUND" => 10,
    # Low - quick fix
    "QUICKFIX" => 11,
    # Low - temporary code
    "TEMP" => 12,
    # Low - temporary code
    "TEMPORARY" => 13,
    # Low - placeholder code
    "PLACEHOLDER" => 14,
    # Low - hidden todo or important info
    "NOTE" => 15
  }

  @doc """
  Extract TODO comments from a single file and create todos.

  ## Examples

      iex> TodoExtractor.extract_from_file("lib/my_module.ex")
      {:ok, [%Todo{title: "Fix this bug", priority: 2}]}

      iex> TodoExtractor.extract_from_file("lib/my_module.ex", patterns: [])
      {:ok, []}
  """
  @spec extract_from_file(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def extract_from_file(file_path, opts \\ []) do
    _patterns = Keyword.get(opts, :patterns, @default_patterns)
    create_todos = Keyword.get(opts, :create_todos, true)

    case AstQualityAnalyzer.find_todo_and_fixme_comments(file_path) do
      {:ok, comments} when comments != [] ->
        # Filter out development artifacts and non-actionable comments
        actionable_comments = filter_actionable_comments(comments)

        if actionable_comments != [] do
          Logger.info(
            "Found #{length(actionable_comments)} actionable TODO comments in #{file_path} (filtered from #{length(comments)} total)"
          )

          todos =
            if create_todos do
              Enum.map(actionable_comments, &create_todo_from_comment(&1, file_path))
            else
              actionable_comments
            end

          {:ok, todos}
        else
          Logger.debug(
            "No actionable TODO comments found in #{file_path} (filtered out #{length(comments)} development artifacts)"
          )

          {:ok, []}
        end

      {:ok, []} ->
        Logger.debug("No TODO comments found in #{file_path}")
        {:ok, []}

      {:error, reason} ->
        Logger.debug("Failed to extract TODOs from #{file_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Extract TODOs from file after it's been updated in database.

  This is called by CodeFileWatcher after a file has been re-ingested
  and the database has been updated with the latest version.

  ## Examples

      iex> TodoExtractor.extract_after_file_update("lib/my_module.ex")
      {:ok, [%Todo{title: "Fix this bug"}]}
  """
  @spec extract_after_file_update(String.t()) :: {:ok, [map()]} | {:error, term()}
  def extract_after_file_update(file_path) do
    Logger.debug("Extracting TODOs from updated file: #{file_path}")
    extract_from_file(file_path, create_todos: true)
  end

  # Private Functions

  defp filter_actionable_comments(comments) do
    comments
    |> Enum.reject(&is_excluded_comment?/1)
    |> Enum.filter(&is_actionable_comment?/1)
  end

  defp is_excluded_comment?(comment) do
    pattern = comment[:pattern] || ""

    # Check if this comment matches any excluded pattern
    Enum.any?(@excluded_patterns, fn {_lang, excluded_pattern, _desc} ->
      String.contains?(pattern, excluded_pattern)
    end)
  end

  defp is_actionable_comment?(comment) do
    pattern = comment[:pattern] || ""
    matched_text = comment[:matched_text] || ""

    # Must be any code smell marker (not excluded)
    is_code_smell =
      String.contains?(pattern, "TODO:") or
        String.contains?(pattern, "FIXME:") or
        String.contains?(pattern, "NOTE:") or
        String.contains?(pattern, "STUB:") or
        String.contains?(pattern, "HACK:") or
        String.contains?(pattern, "DEBUG:") or
        String.contains?(pattern, "DEAD:") or
        String.contains?(pattern, "UNUSED:") or
        String.contains?(pattern, "DEPRECATED:") or
        String.contains?(pattern, "REMOVE:") or
        String.contains?(pattern, "WORKAROUND:") or
        String.contains?(pattern, "QUICKFIX:") or
        String.contains?(pattern, "TEMP:") or
        String.contains?(pattern, "TEMPORARY:") or
        String.contains?(pattern, "PLACEHOLDER:")

    # Must have meaningful content (not just the marker)
    has_content = String.length(String.trim(matched_text)) > 10

    is_code_smell and has_content
  end

  defp create_todo_from_comment(comment, file_path) do
    # Extract TODO text from the comment
    todo_text = extract_todo_text(comment)

    # Check if comment already has a UUID
    existing_uuid = extract_uuid_from_comment(comment)

    # Generate new UUID if none exists
    file_uuid = existing_uuid || generate_uuid()

    # Check if todo with this UUID already exists
    case find_todo_by_file_uuid(file_uuid) do
      nil ->
        # Create new todo
        create_new_todo(comment, file_path, todo_text, file_uuid)

      existing_todo ->
        # Update existing todo if content changed
        update_existing_todo(existing_todo, comment, file_path, todo_text)
    end
  end

  defp extract_todo_text(comment) do
    # Get the matched text and clean it up
    text = comment[:matched_text] || ""

    # Remove the comment prefix and clean up
    text
    |> String.replace(~r/^#\s*(TODO|FIXME|HACK|NOTE):\s*/, "")
    |> String.replace(~r/^\s*\/\/\s*(TODO|FIXME|HACK|NOTE):\s*/, "")
    |> String.trim()
    |> case do
      "" -> "TODO item from #{Path.basename(comment[:file_path] || "")}"
      clean_text -> clean_text
    end
  end

  defp determine_priority(comment) do
    pattern = comment[:pattern] || ""

    case String.split(pattern, ":") do
      [prefix, _] ->
        comment_type = String.trim(prefix) |> String.replace(~r/^[#\/\s]+/, "")
        Map.get(@priority_map, comment_type, 3)

      _ ->
        # Default to medium priority
        3
    end
  end

  defp determine_complexity(todo_text) do
    cond do
      String.length(todo_text) < 20 -> :simple
      String.contains?(todo_text, ["architecture", "refactor", "migrate", "rewrite"]) -> :complex
      String.contains?(todo_text, ["fix", "bug", "error", "issue"]) -> :medium
      true -> :medium
    end
  end

  # UUID handling functions

  defp extract_uuid_from_comment(comment) do
    text = comment[:matched_text] || ""

    # Look for UUID pattern in comment text
    case Regex.run(~r/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i, text) do
      [uuid] -> uuid
      _ -> nil
    end
  end

  defp generate_uuid do
    # Generate a UUID4
    :crypto.strong_rand_bytes(16)
    |> :binary.encode_hex()
    |> String.downcase()
    |> then(fn hex ->
      <<a::binary-size(8), b::binary-size(4), c::binary-size(4), d::binary-size(4),
        e::binary-size(12)>> = hex

      "#{a}-#{b}-#{c}-#{d}-#{e}"
    end)
  end

  defp find_todo_by_file_uuid(file_uuid) do
    import Ecto.Query

    Singularity.Repo.one(
      from t in Singularity.Execution.Todo,
        where: t.file_uuid == ^file_uuid
    )
  end

  defp create_new_todo(comment, file_path, todo_text, file_uuid) do
    priority = determine_priority(comment)
    complexity = determine_complexity(todo_text)

    case TodoStore.create(%{
           title: todo_text,
           description: "Auto-extracted from #{Path.relative_to_cwd(file_path)}",
           priority: priority,
           complexity: complexity,
           status: "pending",
           source: "code_comment",
           file_uuid: file_uuid,
           context: %{
             file_path: file_path,
             line_number: comment[:line] || 0,
             comment_type: comment[:pattern] || "TODO",
             extracted_at: DateTime.utc_now()
           }
         }) do
      {:ok, todo} ->
        Logger.debug("Created todo from comment: #{todo.title} (UUID: #{file_uuid})")
        todo

      {:error, reason} ->
        Logger.debug("Failed to create todo from comment: #{inspect(reason)}")
        %{error: reason, comment: comment}
    end
  end

  defp update_existing_todo(existing_todo, comment, file_path, todo_text) do
    # Check if content has changed
    if existing_todo.title != todo_text do
      # Update the todo with new content
      case TodoStore.update(existing_todo, %{
             title: todo_text,
             context:
               Map.merge(existing_todo.context || %{}, %{
                 file_path: file_path,
                 line_number: comment[:line] || 0,
                 comment_type: comment[:pattern] || "TODO",
                 updated_at: DateTime.utc_now()
               })
           }) do
        {:ok, updated_todo} ->
          Logger.debug(
            "Updated existing todo: #{updated_todo.title} (UUID: #{existing_todo.file_uuid})"
          )

          updated_todo

        {:error, reason} ->
          Logger.debug("Failed to update existing todo: #{inspect(reason)}")
          existing_todo
      end
    else
      # Content unchanged, return existing todo
      Logger.debug("Todo unchanged: #{existing_todo.title} (UUID: #{existing_todo.file_uuid})")
      existing_todo
    end
  end
end
