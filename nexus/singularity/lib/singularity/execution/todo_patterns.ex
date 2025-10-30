defmodule Singularity.Execution.TodoPatterns do
  @moduledoc """
  Shared registry of comment patterns used by TODO extraction.

  Centralises the actionable markers, language-specific comment prefixes, and
  priority mapping so multiple components (extractors, analyzers, workers) stay
  in sync when identifying technical-debt comments across languages.
  """

  @actionable_markers %{
    "TODO" => "incomplete work",
    "FIXME" => "requires a fix",
    "STUB" => "placeholder implementation",
    "HACK" => "temporary workaround",
    "DEBUG" => "debugging artefact",
    "DEAD" => "dead code path",
    "UNUSED" => "unused code path",
    "DEPRECATED" => "deprecated code path",
    "REMOVE" => "code scheduled for removal",
    "WORKAROUND" => "temporary workaround",
    "QUICKFIX" => "quick fix pending permanent solution",
    "TEMP" => "temporary code",
    "TEMPORARY" => "temporary code",
    "PLACEHOLDER" => "placeholder code or comment",
    "NOTE" => "follow-up note"
  }

  @non_actionable_markers %{
    "INFO" => "informational comment",
    "DOC" => "documentation comment",
    "COMMENT" => "explanatory comment",
    "TEST" => "test helper comment",
    "EXAMPLE" => "example snippet",
    "SAMPLE" => "sample snippet"
  }

  @language_prefixes %{
    "elixir" => "#",
    "python" => "#",
    "rust" => "//",
    "javascript" => "//",
    "typescript" => "//",
    "go" => "//",
    "java" => "//",
    "csharp" => "//"
  }

  @priority_map %{
    "FIXME" => 1,
    "TODO" => 2,
    "STUB" => 3,
    "HACK" => 4,
    "DEBUG" => 5,
    "DEAD" => 6,
    "UNUSED" => 7,
    "DEPRECATED" => 8,
    "REMOVE" => 9,
    "WORKAROUND" => 10,
    "QUICKFIX" => 11,
    "TEMP" => 12,
    "TEMPORARY" => 13,
    "PLACEHOLDER" => 14,
    "NOTE" => 15
  }

  @doc """
  Return the language-tag tuples that should generate actionable TODO items.
  """
  @spec actionable_patterns() :: [{String.t(), String.t(), String.t()}]
  def actionable_patterns do
    for {language, prefix} <- @language_prefixes,
        {tag, desc} <- @actionable_markers do
      {language, "#{prefix} #{tag}: $$$", "#{tag} comment - #{desc}"}
    end
  end

  @doc """
  Return comment patterns that should be ignored during extraction.
  """
  @spec excluded_patterns() :: [{String.t(), String.t(), String.t()}]
  def excluded_patterns do
    for {language, prefix} <- @language_prefixes,
        {tag, desc} <- @non_actionable_markers do
      {language, "#{prefix} #{tag}: $$$", "#{tag} comment - #{desc}"}
    end
  end

  @doc """
  Priority mapping shared by executors and storage.
  """
  @spec priority_map() :: map()
  def priority_map, do: @priority_map
end
