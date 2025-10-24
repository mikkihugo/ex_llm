defmodule Mix.Tasks.Rag.Test do
  @moduledoc """
  Test RAG quality-aware code generation with examples.

  ## Usage

      # Quick test
      mix rag.test

      # Test specific task
      mix rag.test --task "Parse JSON with error handling"

      # Test with options
      mix rag.test --language elixir --retries 3 --no-validate

      # Generate multiple examples
      mix rag.test --examples 5

  ## Examples

      # Default test
      mix rag.test

      # Custom task
      mix rag.test --task "Create GenServer for cache"

      # Multiple languages
      mix rag.test --examples 3
  """

  use Mix.Task
  require Logger

  @shortdoc "Test RAG code generation with quality validation"

  @default_tasks [
    {"Parse JSON with error handling", "elixir"},
    {"HTTP request with timeout", "elixir"},
    {"Read file with error handling", "elixir"},
    {"GenServer for cache", "elixir"},
    {"Validate email address", "elixir"}
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          task: :string,
          language: :string,
          validate: :boolean,
          retries: :integer,
          examples: :integer
        ],
        aliases: [t: :task, l: :language, r: :retries, e: :examples]
      )

    Mix.Task.run("app.start")

    task = opts[:task]
    language = opts[:language] || "elixir"
    validate = Keyword.get(opts, :validate, true)
    retries = opts[:retries] || 2
    examples_count = opts[:examples] || 1

    Mix.shell().info("""

    ╔══════════════════════════════════════════════════════════════╗
    ║  RAG Quality-Aware Code Generation - Test                    ║
    ╚══════════════════════════════════════════════════════════════╝
    """)

    if task do
      # Single task test
      test_generation(task, language, validate, retries)
    else
      # Multiple examples test
      test_multiple_examples(examples_count, validate, retries)
    end
  end

  defp test_generation(task, language, validate, retries) do
    Mix.shell().info("""
    Task: #{task}
    Language: #{language}
    Validation: #{validate}
    Max Retries: #{retries}
    """)

    alias Singularity.CodeGeneration.Implementations.RAGCodeGenerator

    start_time = System.monotonic_time(:millisecond)

    result =
      RAGCodeGenerator.generate(
        task: task,
        language: language,
        quality_level: "production",
        validate: validate,
        max_retries: retries
      )

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    case result do
      {:ok, code} ->
        Mix.shell().info("""

        ✅ Generation successful! (#{duration}ms)

        ┌─────────────────────────── Generated Code ───────────────────────────┐
        #{code}
        └──────────────────────────────────────────────────────────────────────┘

        Lines: #{count_lines(code)}
        Size: #{byte_size(code)} bytes
        """)

      {:error, reason} ->
        Mix.shell().error("""

        ❌ Generation failed: #{inspect(reason)}
        """)
    end
  end

  defp test_multiple_examples(count, validate, retries) do
    Mix.shell().info("""
    Running #{count} example test(s)...
    Validation: #{validate}
    Max Retries: #{retries}
    """)

    tasks = Enum.take(@default_tasks, count)

    results =
      Enum.with_index(tasks, 1)
      |> Enum.map(fn {{task, language}, index} ->
        Mix.shell().info("""

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Example #{index}/#{count}: #{task}
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)

        test_generation(task, language, validate, retries)

        # Small delay between requests
        if index < count, do: Process.sleep(1000)

        :ok
      end)

    success_count = Enum.count(results, &(&1 == :ok))

    Mix.shell().info("""

    ═══════════════════════════════════════════════════════════════
    Summary: #{success_count}/#{count} tests completed
    ═══════════════════════════════════════════════════════════════
    """)
  end

  defp count_lines(code) do
    code
    |> String.split("\n")
    |> length()
  end
end
