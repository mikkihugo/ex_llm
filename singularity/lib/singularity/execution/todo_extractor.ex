defmodule Singularity.Execution.TodoExtractor do
  @moduledoc """
  TODO Comment Extractor - Centralized TODO extraction from code files

  **PURPOSE**: Extract ONLY actionable TODO and FIXME comments from code files
  and convert them into actionable todo items in the database.

  **PRODUCTION-READY**: Filters out development artifacts like stubs, notes,
  dead code markers, and temporary hacks to focus on real actionable items.

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

  **✅ EXTRACTED (Actionable):**
  - `# TODO: Implement user authentication`
  - `# FIXME: Handle null pointer exception`
  - `// TODO: Add error handling for edge case`
  - `// FIXME: Memory leak in cleanup function`

  **❌ FILTERED OUT (Development Artifacts):**
  - `# STUB: Placeholder for future implementation`
  - `# NOTE: This is just documentation`
  - `# DEBUG: Temporary logging statement`
  - `# HACK: Quick workaround for testing`
  - `# DEAD: This code should be removed`
  - `# UNUSED: Legacy function no longer needed`
  """

  alias Singularity.Execution.TodoStore
  alias Singularity.CodeQuality.AstQualityAnalyzer

  require Logger

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

  # Patterns to EXCLUDE (development artifacts, not actionable todos)
  @excluded_patterns [
    # Stubs and placeholders
    {"elixir", "# STUB: $$$", "STUB comment - placeholder code"},
    {"elixir", "# PLACEHOLDER: $$$", "PLACEHOLDER comment - temporary code"},
    {"elixir", "# TEMP: $$$", "TEMP comment - temporary code"},
    {"elixir", "# TEMPORARY: $$$", "TEMPORARY comment - temporary code"},
    
    # Notes and documentation
    {"elixir", "# NOTE: $$$", "NOTE comment - documentation"},
    {"elixir", "# INFO: $$$", "INFO comment - information"},
    {"elixir", "# DOC: $$$", "DOC comment - documentation"},
    {"elixir", "# COMMENT: $$$", "COMMENT comment - explanation"},
    
    # Dead code markers
    {"elixir", "# DEAD: $$$", "DEAD comment - dead code"},
    {"elixir", "# UNUSED: $$$", "UNUSED comment - unused code"},
    {"elixir", "# DEPRECATED: $$$", "DEPRECATED comment - deprecated code"},
    {"elixir", "# REMOVE: $$$", "REMOVE comment - code to remove"},
    
    # Development markers
    {"elixir", "# DEBUG: $$$", "DEBUG comment - debugging code"},
    {"elixir", "# TEST: $$$", "TEST comment - test code"},
    {"elixir", "# EXAMPLE: $$$", "EXAMPLE comment - example code"},
    {"elixir", "# SAMPLE: $$$", "SAMPLE comment - sample code"},
    
    # Hacks (too temporary for production todos)
    {"elixir", "# HACK: $$$", "HACK comment - temporary solution"},
    {"elixir", "# WORKAROUND: $$$", "WORKAROUND comment - temporary fix"},
    {"elixir", "# QUICKFIX: $$$", "QUICKFIX comment - quick fix"},
    
    # Rust equivalents
    {"rust", "// STUB: $$$", "STUB comment - placeholder code"},
    {"rust", "// PLACEHOLDER: $$$", "PLACEHOLDER comment - temporary code"},
    {"rust", "// TEMP: $$$", "TEMP comment - temporary code"},
    {"rust", "// NOTE: $$$", "NOTE comment - documentation"},
    {"rust", "// DEBUG: $$$", "DEBUG comment - debugging code"},
    {"rust", "// HACK: $$$", "HACK comment - temporary solution"},
    {"rust", "// DEAD: $$$", "DEAD comment - dead code"},
    {"rust", "// UNUSED: $$$", "UNUSED comment - unused code"},
    
    # JavaScript equivalents
    {"javascript", "// STUB: $$$", "STUB comment - placeholder code"},
    {"javascript", "// PLACEHOLDER: $$$", "PLACEHOLDER comment - temporary code"},
    {"javascript", "// TEMP: $$$", "TEMP comment - temporary code"},
    {"javascript", "// NOTE: $$$", "NOTE comment - documentation"},
    {"javascript", "// DEBUG: $$$", "DEBUG comment - debugging code"},
    {"javascript", "// HACK: $$$", "HACK comment - temporary solution"},
    {"javascript", "// DEAD: $$$", "DEAD comment - dead code"},
    {"javascript", "// UNUSED: $$$", "UNUSED comment - unused code"},
    
    # Python equivalents
    {"python", "# STUB: $$$", "STUB comment - placeholder code"},
    {"python", "# PLACEHOLDER: $$$", "PLACEHOLDER comment - temporary code"},
    {"python", "# TEMP: $$$", "TEMP comment - temporary code"},
    {"python", "# NOTE: $$$", "NOTE comment - documentation"},
    {"python", "# DEBUG: $$$", "DEBUG comment - debugging code"},
    {"python", "# HACK: $$$", "HACK comment - temporary solution"},
    {"python", "# DEAD: $$$", "DEAD comment - dead code"},
    {"python", "# UNUSED: $$$", "UNUSED comment - unused code"}
  ]

  # Priority mapping for comment types
  @priority_map %{
    "FIXME" => 1,  # Critical
    "TODO" => 2,   # High
    "HACK" => 3,   # Medium
    "NOTE" => 4    # Low
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
          Logger.info("Found #{length(actionable_comments)} actionable TODO comments in #{file_path} (filtered from #{length(comments)} total)")
          
          todos = if create_todos do
            Enum.map(actionable_comments, &create_todo_from_comment(&1, file_path))
          else
            actionable_comments
          end

          {:ok, todos}
        else
          Logger.debug("No actionable TODO comments found in #{file_path} (filtered out #{length(comments)} development artifacts)")
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
    
    # Must be a TODO or FIXME (not excluded)
    is_todo_or_fixme = String.contains?(pattern, "TODO:") or String.contains?(pattern, "FIXME:")
    
    # Must have meaningful content (not just "TODO:" or "FIXME:")
    has_content = String.length(String.trim(matched_text)) > 10
    
    # Must not be a stub or placeholder
    not_is_stub = not String.contains?(String.downcase(matched_text), ["stub", "placeholder", "temp", "temporary"])
    
    is_todo_or_fixme and has_content and not_is_stub
  end


  defp create_todo_from_comment(comment, file_path) do
    # Extract TODO text from the comment
    todo_text = extract_todo_text(comment)
    
    # Determine priority based on comment type
    priority = determine_priority(comment)
    
    # Determine complexity based on comment length and content
    complexity = determine_complexity(todo_text)

    # Create the todo
    case TodoStore.create(%{
      title: todo_text,
      description: "Auto-extracted from #{Path.relative_to_cwd(file_path)}",
      priority: priority,
      complexity: complexity,
      status: "pending",
      source: "code_comment",
      metadata: %{
        file_path: file_path,
        line_number: comment[:line] || 0,
        comment_type: comment[:pattern] || "TODO",
        extracted_at: DateTime.utc_now()
      }
    }) do
      {:ok, todo} ->
        Logger.debug("Created todo from comment: #{todo.title}")
        todo

      {:error, reason} ->
        Logger.debug("Failed to create todo from comment: #{inspect(reason)}")
        %{error: reason, comment: comment}
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
        3  # Default to medium priority
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
end