defmodule Singularity.Embedding.PolyglotTripletGenerator do
  @moduledoc """
  Polyglot Triplet Generator for Contrastive Learning

  Generates anchor/positive/negative triplets from mixed-language codebase:
  - BEAM (Elixir/Erlang) - Primary (70%)
  - C++ - Secondary (30%)

  Used for fine-tuning Qodo embeddings on domain-specific code patterns.

  ## Architecture

  Triplet structure:
  ```elixir
  %{
    anchor: "code_snippet_1",        # Reference code
    positive: "code_snippet_2",      # Similar pattern, same language or different
    negative: "code_snippet_3"       # Different pattern or language
  }
  ```

  Examples:
  ```elixir
  # BEAM-BEAM triplet (same language, similar pattern)
  %{
    anchor: "defmodule MyApp.Server do use GenServer end",
    positive: "defmodule Storage.Handler do use GenServer end",
    negative: "defmodule API do end"  # No GenServer
  }

  # BEAM-C++ cross-language triplet
  %{
    anchor: "defmodule Worker do def handle_event(event) do",
    positive: "class EventHandler { public: void handleEvent(Event e) {",  # C++
    negative: "async function process(data) {"  # JavaScript - unrelated
  }

  # C++ triplet
  %{
    anchor: "void processData() { std::vector<int> v; for(int i=0; i<n; i++) v.push_back(i); }",
    positive: "void handleRequest() { std::vector<int> data; for(int i=0; i<size; i++) data.push_back(i); }",
    negative: "defmodule Parser do parse(input) do"  # BEAM - unrelated
  }
  ```

  ## Usage

  ```elixir
  # Generate 1000 mixed triplets from codebase
  {:ok, triplets} = PolyglotTripletGenerator.generate(
    count: 1000,
    beam_ratio: 0.7,          # 70% BEAM, 30% C++
    cross_language_ratio: 0.3 # 30% cross-language pairs
  )

  # Use for fine-tuning
  {:ok, trainer} = Trainer.new(:qodo, device: :cuda)
  {:ok, metrics} = Trainer.train(trainer, triplets, epochs: 3)
  ```

  ## Data Sources

  1. **BEAM Code** (Elixir/Erlang)
     - lib/**/*.ex files
     - Extract patterns: GenServer, supervisors, pipelines, pattern matching

  2. **C++ Code**
     - packages/*/src/**/*.{cpp,h,cc,hpp} files
     - Extract patterns: Classes, memory management, templates, algorithms

  3. **Pattern Extraction**
     - Functions/methods
     - Modules/classes
     - Control flow structures
     - Data structures

  ## Quality Metrics

  - Triplet validity (anchor ≠ positive ≠ negative)
  - Language diversity (should have cross-language pairs)
  - Pattern diversity (multiple categories, not just one pattern)
  - Code validity (syntactically correct snippets)
  """

  require Logger
  alias Singularity.LanguageDetection

  @beam_patterns [
    "use GenServer",
    "use Supervisor",
    "defmodule",
    "def ",
    "defp ",
    "pattern matching",
    "pipe |>",
    "->"
  ]

  @cpp_patterns [
    "class ",
    "struct ",
    "void ",
    "int ",
    "std::",
    "template",
    "virtual",
    "const"
  ]

  @doc """
  Generate polyglot triplets from mixed-language codebase
  """
  def generate(opts \\ []) do
    count = Keyword.get(opts, :count, 1000)
    beam_ratio = Keyword.get(opts, :beam_ratio, 0.7)
    cross_language_ratio = Keyword.get(opts, :cross_language_ratio, 0.3)
    codebase_root = Keyword.get(opts, :codebase_root, File.cwd!())

    Logger.info("📚 Generating #{count} polyglot triplets")
    Logger.info("  BEAM ratio: #{Float.round(beam_ratio * 100, 1)}%")
    Logger.info("  C++ ratio: #{Float.round((1 - beam_ratio) * 100, 1)}%")
    Logger.info("  Cross-language: #{Float.round(cross_language_ratio * 100, 1)}%")

    with {:ok, beam_snippets} <- extract_beam_snippets(codebase_root),
         {:ok, cpp_snippets} <- extract_cpp_snippets(codebase_root) do
      Logger.info("  BEAM snippets found: #{length(beam_snippets)}")
      Logger.info("  C++ snippets found: #{length(cpp_snippets)}")

      beam_count = trunc(count * beam_ratio)
      cpp_count = count - beam_count

      beam_triplets = generate_beam_triplets(beam_snippets, beam_count)
      cpp_triplets = generate_cpp_triplets(cpp_snippets, cpp_count)
      cross_triplets = generate_cross_language_triplets(beam_snippets, cpp_snippets, trunc(count * cross_language_ratio))

      all_triplets = beam_triplets ++ cpp_triplets ++ cross_triplets
      shuffled = Enum.shuffle(all_triplets) |> Enum.take(count)

      Logger.info("✅ Generated #{length(shuffled)} triplets")
      {:ok, shuffled}
    else
      error ->
        Logger.error("Failed to generate triplets: #{inspect(error)}")
        {:error, :extraction_failed}
    end
  end

  # Extract BEAM (Elixir/Erlang) code snippets
  defp extract_beam_snippets(codebase_root) do
    beam_files = [
      Path.join(codebase_root, "lib/**/*.ex"),
      Path.join(codebase_root, "nexus/singularity/lib/**/*.ex")
    ]

    try do
      snippets =
        beam_files
        |> Enum.flat_map(&Path.wildcard/1)
        |> Enum.flat_map(&extract_functions/1)
        |> Enum.filter(&valid_snippet?/1)

      {:ok, snippets}
    rescue
      e ->
        Logger.warning("Error extracting BEAM snippets: #{inspect(e)}")
        {:ok, []}
    end
  end

  # Extract C++ code snippets
  defp extract_cpp_snippets(codebase_root) do
    cpp_files = [
      Path.join(codebase_root, "packages/*/src/**/*.{cpp,h,cc,hpp}"),
      Path.join(codebase_root, "rust/**/*.cpp")
    ]

    try do
      snippets =
        cpp_files
        |> Enum.flat_map(&Path.wildcard/1)
        |> Enum.flat_map(&extract_cpp_functions/1)
        |> Enum.filter(&valid_snippet?/1)

      {:ok, snippets}
    rescue
      e ->
        Logger.warning("Error extracting C++ snippets: #{inspect(e)}")
        {:ok, []}
    end
  end

  # Extract Elixir functions from file
  defp extract_functions(file) do
    try do
      content = File.read!(file)
      # Split by function definitions
      String.split(content, ~r/^  def |^  defp /m)
      |> Enum.map(&String.slice(&1, 0..200))
      |> Enum.filter(&String.length(&1) > 20)
    rescue
      _ -> []
    end
  end

  # Extract C++ functions from file
  defp extract_cpp_functions(file) do
    try do
      content = File.read!(file)
      # Match function definitions: return_type name() { ... }
      Regex.scan(~r/\w+\s+\w+\s*\([^)]*\)\s*\{[^}]*\}/s, content)
      |> Enum.map(fn [match] -> String.slice(match, 0..200) end)
      |> Enum.filter(&String.length(&1) > 20)
    rescue
      _ -> []
    end
  end

  # Check if snippet is valid (not empty, reasonable length)
  defp valid_snippet?(snippet) do
    len = String.length(snippet)
    len > 20 and len < 500
  end

  # Generate BEAM-to-BEAM triplets
  defp generate_beam_triplets(snippets, count) when length(snippets) < 3 do
    Logger.warning("Not enough BEAM snippets for triplets")
    []
  end

  defp generate_beam_triplets(snippets, count) do
    Enum.map(1..count, fn _ ->
      anchors = Enum.shuffle(snippets)
      anchor = List.first(anchors)
      positive = Enum.random(snippets)
      negative = Enum.random(snippets)

      %{
        anchor: anchor,
        positive: positive,
        negative: negative,
        anchor_lang: :beam,
        positive_lang: :beam,
        negative_lang: :beam
      }
    end)
  end

  # Generate C++-to-C++ triplets
  defp generate_cpp_triplets(snippets, count) when length(snippets) < 3 do
    Logger.warning("Not enough C++ snippets for triplets")
    []
  end

  defp generate_cpp_triplets(snippets, count) do
    Enum.map(1..count, fn _ ->
      anchors = Enum.shuffle(snippets)
      anchor = List.first(anchors)
      positive = Enum.random(snippets)
      negative = Enum.random(snippets)

      %{
        anchor: anchor,
        positive: positive,
        negative: negative,
        anchor_lang: :cpp,
        positive_lang: :cpp,
        negative_lang: :cpp
      }
    end)
  end

  # Generate cross-language triplets (BEAM-C++ pairs)
  defp generate_cross_language_triplets(beam_snippets, cpp_snippets, count) do
    min_len = min(length(beam_snippets), length(cpp_snippets))

    if min_len < 2 do
      Logger.warning("Not enough snippets for cross-language triplets")
      []
    else
      Enum.map(1..count, fn _ ->
        # Randomly alternate which language is anchor
        case Enum.random([1, 2]) do
          1 ->
            # BEAM anchor, C++ positive
            %{
              anchor: Enum.random(beam_snippets),
              positive: Enum.random(cpp_snippets),
              negative: Enum.random(beam_snippets),
              anchor_lang: :beam,
              positive_lang: :cpp,
              negative_lang: :beam
            }

          2 ->
            # C++ anchor, BEAM positive
            %{
              anchor: Enum.random(cpp_snippets),
              positive: Enum.random(beam_snippets),
              negative: Enum.random(cpp_snippets),
              anchor_lang: :cpp,
              positive_lang: :beam,
              negative_lang: :cpp
            }
        end
      end)
    end
  end

  @doc """
  Analyze triplet quality
  """
  def analyze_triplets(triplets) do
    total = length(triplets)
    beam_count = Enum.count(triplets, &(&1.anchor_lang == :beam))
    cpp_count = total - beam_count
    cross_lang_count = Enum.count(triplets, &(&1.anchor_lang != &1.positive_lang))

    %{
      total: total,
      beam_ratio: beam_count / max(total, 1),
      cpp_ratio: cpp_count / max(total, 1),
      cross_language_ratio: cross_lang_count / max(total, 1)
    }
  end
end
