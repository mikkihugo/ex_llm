#!/usr/bin/env elixir

# TODO Validation Script
# Purpose: Find outdated TODOs that reference already-implemented features
# Usage: elixir scripts/validate_todos.exs

defmodule TodoValidator do
  @moduledoc """
  Validates TODOs in the codebase by checking if referenced features exist.

  Identifies outdated TODOs that mention features that are already implemented,
  helping maintain accurate technical debt tracking.
  """

  # Features to check for (module pattern -> feature name)
  @features %{
    # Embedding features
    ~r/embedding|embed/ => %{
      name: "Embedding Service",
      modules: [
        "lib/singularity/llm/embedding_generator.ex",
        "lib/singularity/search/unified_embedding_service.ex",
        "lib/singularity/embedding_model_loader.ex",
        "lib/singularity/engines/embedding_engine.ex"
      ],
      keywords: ["embedding", "embed", "vector"]
    },

    # NATS features
    ~r/nats|messaging/ => %{
      name: "NATS Messaging",
      modules: [
        "lib/singularity/nats/nats_client.ex",
        "lib/singularity/nats/nats_server.ex",
        "lib/singularity/nats/nats_execution_router.ex",
        "lib/singularity/interfaces/nats.ex"
      ],
      keywords: ["nats", "messaging", "publish", "subscribe"]
    },

    # Semantic search
    ~r/semantic.*search|search.*semantic/ => %{
      name: "Semantic Search",
      modules: [
        "lib/singularity/engines/semantic_engine.ex",
        "lib/singularity/search/unified_embedding_service.ex",
        "lib/singularity/search/postgres_vector_search.ex"
      ],
      keywords: ["semantic search", "code search", "similarity"]
    },

    # Code analysis
    ~r/code.*analysis|analyze.*code|parser|parsing/ => %{
      name: "Code Analysis",
      modules: [
        "lib/singularity/code_analyzer.ex",
        "lib/singularity/engines/code_quality_engine_nif.ex",
        "rust/code_quality_engine/"
      ],
      keywords: ["code analysis", "parser", "ast", "tree-sitter"]
    },

    # Quality/templates
    ~r/quality|template/ => %{
      name: "Quality Templates",
      modules: [
        "lib/singularity/knowledge/template_service.ex",
        "lib/singularity/storage/code/quality/",
        "templates_data/"
      ],
      keywords: ["quality", "template", "code generation"]
    },

    # Database/Ecto
    ~r/database|ecto|repo|migration/ => %{
      name: "Database Infrastructure",
      modules: [
        "lib/singularity/repo.ex",
        "priv/repo/migrations/"
      ],
      keywords: ["database", "ecto", "postgres", "migration"]
    },

    # Caching
    ~r/cache|caching/ => %{
      name: "Caching Infrastructure",
      modules: [
        "lib/singularity/storage/cache.ex",
        "lib/singularity/llm/prompt/cache.ex"
      ],
      keywords: ["cache", "caching", "memoization"]
    }
  }

  def run do
    IO.puts("\n🔍 TODO Validation Report")
    IO.puts("=" <> String.duplicate("=", 60))

    # Find all TODOs
    todos = find_all_todos()

    IO.puts("\n📊 Statistics:")
    IO.puts("  Total TODOs found: #{length(todos)}")

    # Validate features exist
    IO.puts("\n✅ Feature Existence Check:")
    feature_status = check_feature_existence()

    Enum.each(feature_status, fn {feature_name, exists?, modules} ->
      status_icon = if exists?, do: "✅", else: "❌"
      IO.puts("  #{status_icon} #{feature_name}")

      if exists? do
        IO.puts("     Found #{length(modules)} implementation files")
      end
    end)

    # Find potentially outdated TODOs
    IO.puts("\n🔍 Potentially Outdated TODOs:")
    outdated = find_outdated_todos(todos, feature_status)

    if Enum.empty?(outdated) do
      IO.puts("  ✨ No obviously outdated TODOs found!")
    else
      IO.puts("  Found #{length(outdated)} potentially outdated TODOs:\n")

      outdated
      |> Enum.group_by(fn {_file, _line, _text, feature} -> feature end)
      |> Enum.each(fn {feature, todos_list} ->
        IO.puts("  📦 #{feature} (#{length(todos_list)} TODOs):")

        Enum.each(todos_list, fn {file, line, text, _} ->
          short_file = String.replace(file, "lib/singularity/", "")
          IO.puts("     • #{short_file}:#{line}")
          IO.puts("       \"#{String.trim(text)}\"")
        end)

        IO.puts("")
      end)
    end

    # Summary
    IO.puts("\n📈 Summary:")
    IO.puts("  Total TODOs: #{length(todos)}")

    IO.puts(
      "  Potentially outdated: #{length(outdated)} (#{percentage(length(outdated), length(todos))}%)"
    )

    IO.puts(
      "  Still valid: #{length(todos) - length(outdated)} (#{percentage(length(todos) - length(outdated), length(todos))}%)"
    )

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("💡 Next Steps:")
    IO.puts("  1. Review potentially outdated TODOs above")
    IO.puts("  2. Remove TODOs for features that are fully implemented")
    IO.puts("  3. Update TODOs that need refinement")
    IO.puts("  4. Keep valid TODOs that represent actual work")
    IO.puts("")
  end

  defp find_all_todos do
    {result, 0} =
      System.cmd(
        "grep",
        [
          "-rn",
          "# TODO",
          "--include=*.ex",
          "--include=*.exs",
          "lib/"
        ],
        stderr_to_stdout: true
      )

    result
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_todo_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_todo_line(line) do
    case String.split(line, ":", parts: 3) do
      [file, line_num, text] ->
        {file, String.to_integer(line_num), text}

      _ ->
        nil
    end
  end

  defp check_feature_existence do
    Enum.map(@features, fn {_pattern, %{name: name, modules: modules}} ->
      exists_modules =
        modules
        |> Enum.filter(&file_or_dir_exists?/1)

      {name, !Enum.empty?(exists_modules), exists_modules}
    end)
  end

  defp file_or_dir_exists?(path) do
    File.exists?(path) || File.dir?(path)
  end

  defp find_outdated_todos(todos, feature_status) do
    # Build map of feature names to existence status
    feature_map =
      feature_status
      |> Enum.into(%{}, fn {name, exists?, _} -> {name, exists?} end)

    # Find TODOs that mention implemented features
    todos
    |> Enum.flat_map(fn {file, line, text} ->
      @features
      |> Enum.filter(fn {pattern, %{name: feature_name}} ->
        # Check if TODO mentions this feature AND feature is implemented
        text_lower = String.downcase(text)
        Regex.match?(pattern, text_lower) && Map.get(feature_map, feature_name, false)
      end)
      |> Enum.map(fn {_, %{name: feature_name}} ->
        {file, line, text, feature_name}
      end)
    end)
  end

  defp percentage(num, total) when total > 0 do
    Float.round(num / total * 100, 1)
  end

  defp percentage(_, _), do: 0.0
end

# Run validation
TodoValidator.run()
