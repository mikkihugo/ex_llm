defmodule Singularity.CodeAnalysis.TodoDetector do
  @moduledoc """
  Detects TODO items, incomplete implementations, and missing components
  across singularity-engine services to prioritize development work.
  """

  require Logger

  alias Singularity.Engine.CodebaseStore

  @doc "Scan for TODO items in a service"
  def scan_for_todos(service_path) do
    Logger.info("Scanning for TODOs in service: #{service_path}")

    with {:ok, source_files} <- find_source_files(service_path),
         {:ok, todos} <- extract_todos_from_files(source_files) do
      %{
        service_path: service_path,
        total_todos: length(todos),
        todos_by_priority: group_todos_by_priority(todos),
        todos_by_type: group_todos_by_type(todos),
        todos: todos,
        scan_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to scan TODOs: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Categorize TODO items by type and priority"
  def categorize_todo_items(todos) do
    Logger.info("Categorizing #{length(todos)} TODO items")

    %{
      by_type: group_todos_by_type(todos),
      by_priority: group_todos_by_priority(todos),
      by_complexity: group_todos_by_complexity(todos),
      by_estimated_effort: estimate_effort_for_todos(todos)
    }
  end

  @doc "Prioritize implementation order for TODOs"
  def prioritize_implementation_order(todos) do
    Logger.info("Prioritizing #{length(todos)} TODO items")

    # Score each TODO based on multiple factors
    scored_todos =
      Enum.map(todos, fn todo ->
        score = calculate_todo_priority_score(todo)
        Map.put(todo, :priority_score, score)
      end)

    # Sort by priority score (highest first)
    sorted_todos = Enum.sort_by(scored_todos, & &1.priority_score, :desc)

    %{
      prioritized_todos: sorted_todos,
      implementation_phases: group_into_phases(sorted_todos),
      estimated_timeline: estimate_implementation_timeline(sorted_todos)
    }
  end

  @doc "Detect missing critical components"
  def detect_missing_components(service_path) do
    Logger.info("Detecting missing components in: #{service_path}")

    missing = []

    # Check for critical files
    missing = check_critical_files(service_path, missing)

    # Check for required directories
    missing = check_required_directories(service_path, missing)

    # Check for configuration files
    missing = check_configuration_files(service_path, missing)

    %{
      service_path: service_path,
      missing_components: missing,
      criticality_score: calculate_criticality_score(missing),
      detection_timestamp: DateTime.utc_now()
    }
  end

  ## Private Functions

  defp find_source_files(service_path) do
    # Find all source files based on service type
    source_patterns = [
      "**/*.ts",
      "**/*.tsx",
      "**/*.js",
      "**/*.jsx",
      "**/*.rs",
      "**/*.py",
      "**/*.go",
      "**/*.ex",
      "**/*.exs"
    ]

    files =
      Enum.flat_map(source_patterns, fn pattern ->
        Path.wildcard(Path.join(service_path, pattern))
      end)
      |> Enum.reject(&String.contains?(&1, "node_modules"))
      |> Enum.reject(&String.contains?(&1, "target"))
      |> Enum.reject(&String.contains?(&1, "__pycache__"))
      |> Enum.reject(&String.contains?(&1, ".git"))

    {:ok, files}
  end

  defp extract_todos_from_files(files) do
    todos =
      Enum.flat_map(files, fn file_path ->
        extract_todos_from_file(file_path)
      end)

    {:ok, todos}
  end

  defp extract_todos_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        extract_todos_from_content(file_path, content)

      {:error, _} ->
        []
    end
  end

  defp extract_todos_from_content(file_path, content) do
    lines = String.split(content, "\n")

    Enum.with_index(lines, 1)
    |> Enum.flat_map(fn {line, line_number} ->
      extract_todos_from_line(file_path, line, line_number)
    end)
  end

  defp extract_todos_from_line(file_path, line, line_number) do
    # Match various TODO patterns
    patterns = [
      ~r/\/\/\s*TODO[:\s]*(.+)/i,
      ~r/\/\*\s*TODO[:\s]*(.+?)\s*\*\//i,
      ~r/#\s*TODO[:\s]*(.+)/i,
      ~r/\/\/\s*FIXME[:\s]*(.+)/i,
      ~r/\/\/\s*HACK[:\s]*(.+)/i,
      ~r/\/\/\s*NOTE[:\s]*(.+)/i,
      ~r/\/\/\s*XXX[:\s]*(.+)/i
    ]

    Enum.flat_map(patterns, fn pattern ->
      case Regex.run(pattern, line) do
        [_, todo_text] ->
          [
            %{
              file_path: file_path,
              line_number: line_number,
              todo_text: String.trim(todo_text),
              todo_type: determine_todo_type(todo_text),
              priority: determine_todo_priority(todo_text),
              complexity: estimate_todo_complexity(todo_text),
              context: extract_context(line)
            }
          ]

        _ ->
          []
      end
    end)
  end

  defp determine_todo_type(todo_text) do
    text_lower = String.downcase(todo_text)

    cond do
      String.contains?(text_lower, "implement") -> :implementation
      String.contains?(text_lower, "fix") -> :bug_fix
      String.contains?(text_lower, "refactor") -> :refactoring
      String.contains?(text_lower, "optimize") -> :optimization
      String.contains?(text_lower, "test") -> :testing
      String.contains?(text_lower, "document") -> :documentation
      String.contains?(text_lower, "security") -> :security
      String.contains?(text_lower, "performance") -> :performance
      true -> :general
    end
  end

  defp determine_todo_priority(todo_text) do
    text_lower = String.downcase(todo_text)

    cond do
      String.contains?(text_lower, "critical") or String.contains?(text_lower, "urgent") ->
        :critical

      String.contains?(text_lower, "high") or String.contains?(text_lower, "important") ->
        :high

      String.contains?(text_lower, "medium") or String.contains?(text_lower, "normal") ->
        :medium

      String.contains?(text_lower, "low") or String.contains?(text_lower, "minor") ->
        :low

      true ->
        :medium
    end
  end

  defp estimate_todo_complexity(todo_text) do
    text_lower = String.downcase(todo_text)

    cond do
      String.contains?(text_lower, "simple") or String.contains?(text_lower, "easy") ->
        :simple

      String.contains?(text_lower, "complex") or String.contains?(text_lower, "difficult") ->
        :complex

      String.contains?(text_lower, "major") or String.contains?(text_lower, "large") ->
        :major

      true ->
        :medium
    end
  end

  defp extract_context(line) do
    # Extract surrounding context
    String.trim(line)
  end

  defp group_todos_by_priority(todos) do
    Enum.group_by(todos, & &1.priority)
  end

  defp group_todos_by_type(todos) do
    Enum.group_by(todos, & &1.todo_type)
  end

  defp group_todos_by_complexity(todos) do
    Enum.group_by(todos, & &1.complexity)
  end

  defp estimate_effort_for_todos(todos) do
    Enum.map(todos, fn todo ->
      effort_hours =
        case {todo.complexity, todo.todo_type} do
          {:simple, :documentation} -> 0.5
          {:simple, :testing} -> 1.0
          {:simple, :implementation} -> 2.0
          {:medium, :implementation} -> 4.0
          {:medium, :refactoring} -> 6.0
          {:complex, :implementation} -> 8.0
          {:complex, :refactoring} -> 12.0
          {:major, :implementation} -> 16.0
          {:major, :refactoring} -> 24.0
          _ -> 4.0
        end

      Map.put(todo, :estimated_effort_hours, effort_hours)
    end)
  end

  defp calculate_todo_priority_score(todo) do
    priority_score =
      case todo.priority do
        :critical -> 100
        :high -> 75
        :medium -> 50
        :low -> 25
      end

    complexity_score =
      case todo.complexity do
        :simple -> 10
        :medium -> 20
        :complex -> 30
        :major -> 40
      end

    type_score =
      case todo.todo_type do
        :security -> 50
        :bug_fix -> 40
        :implementation -> 30
        :refactoring -> 25
        :optimization -> 20
        :testing -> 15
        :documentation -> 10
        :general -> 5
      end

    priority_score + complexity_score + type_score
  end

  defp group_into_phases(todos) do
    # Group TODOs into implementation phases
    %{
      # Top 1/3
      phase_1: Enum.take(todos, div(length(todos), 3)),
      # Middle 1/3
      phase_2: Enum.slice(todos, div(length(todos), 3), div(length(todos), 3)),
      # Bottom 1/3
      phase_3: Enum.drop(todos, div(length(todos) * 2, 3))
    }
  end

  defp estimate_implementation_timeline(todos) do
    total_effort = Enum.sum(Enum.map(todos, & &1.estimated_effort_hours))

    %{
      total_effort_hours: total_effort,
      # Assuming 40 hours per week
      estimated_weeks: Float.ceil(total_effort / 40, 1),
      # Assuming 160 hours per month
      estimated_months: Float.ceil(total_effort / 160, 1),
      critical_path: identify_critical_path(todos)
    }
  end

  defp identify_critical_path(todos) do
    # Identify TODOs that block other work
    critical_todos =
      Enum.filter(todos, fn todo ->
        String.contains?(String.downcase(todo.todo_text), "block") or
          String.contains?(String.downcase(todo.todo_text), "dependency") or
          String.contains?(String.downcase(todo.todo_text), "required")
      end)

    critical_todos
  end

  defp check_critical_files(service_path, missing) do
    critical_files = [
      "README.md",
      "package.json",
      "project.json",
      "Dockerfile",
      "docker-compose.yml",
      "tsconfig.json",
      "Cargo.toml",
      "requirements.txt",
      "go.mod"
    ]

    Enum.reduce(critical_files, missing, fn file, acc ->
      if not File.exists?(Path.join(service_path, file)) do
        [%{type: :missing_file, name: file, criticality: :high} | acc]
      else
        acc
      end
    end)
  end

  defp check_required_directories(service_path, missing) do
    required_dirs = [
      "src",
      "tests",
      "docs"
    ]

    Enum.reduce(required_dirs, missing, fn dir, acc ->
      dir_path = Path.join(service_path, dir)

      if not File.exists?(dir_path) or not File.dir?(dir_path) do
        [%{type: :missing_directory, name: dir, criticality: :medium} | acc]
      else
        acc
      end
    end)
  end

  defp check_configuration_files(service_path, missing) do
    config_files = [
      ".env",
      ".env.example",
      "config.json",
      "app.config.js"
    ]

    Enum.reduce(config_files, missing, fn file, acc ->
      if not File.exists?(Path.join(service_path, file)) do
        [%{type: :missing_config, name: file, criticality: :medium} | acc]
      else
        acc
      end
    end)
  end

  defp calculate_criticality_score(missing_components) do
    Enum.reduce(missing_components, 0, fn component, score ->
      case component.criticality do
        :high -> score + 10
        :medium -> score + 5
        :low -> score + 1
      end
    end)
  end
end
