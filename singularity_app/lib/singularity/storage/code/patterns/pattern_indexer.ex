defmodule Singularity.PatternIndexer do
  @moduledoc """
  Index semantic patterns from quality templates into vector database

  Takes compact pseudocode patterns from templates and creates embeddings,
  making them searchable for RAG code generation.

  ## Why?

  Patterns like "GenServer → state → get/put" become vectors that:
  - Match user queries ("I need a cache with state")
  - Connect to actual code examples in your repos
  - Guide code generation with architectural knowledge

  ## Usage

      # Index all patterns from templates
      {:ok, count} = PatternIndexer.index_all_templates()

      # Search for patterns
      {:ok, patterns} = PatternIndexer.search("cache with TTL")
      # Returns: [%{pattern: "GenServer cache", pseudocode: "...", relevance: 0.92}]

      # Use patterns for code generation
      {:ok, code} = PatternIndexer.generate_with_patterns(
        "Create a cache with TTL",
        language: "elixir"
      )
  """

  require Logger
  alias Singularity.{EmbeddingEngine, Repo}

  @templates_dir "priv/code_quality_templates"

  @doc """
  Index all semantic patterns from quality templates into vector database

  Creates embeddings for:
  - Pattern pseudocode
  - Relationship descriptions
  - Architectural hints
  - Keywords (for hybrid search)
  """
  @spec index_all_templates() :: {:ok, integer()} | {:error, term()}
  def index_all_templates do
    Logger.info("Indexing semantic patterns from quality templates...")

    templates = load_all_templates()

    patterns =
      templates
      |> Enum.flat_map(&extract_patterns/1)
      |> Enum.uniq_by(& &1.id)

    Logger.info("Found #{length(patterns)} unique patterns to index")

    # Index each pattern
    indexed =
      Enum.reduce(patterns, 0, fn pattern, acc ->
        case index_pattern(pattern) do
          {:ok, _} ->
            acc + 1

          {:error, reason} ->
            Logger.warning("Failed to index pattern: #{inspect(reason)}")
            acc
        end
      end)

    Logger.info("✅ Indexed #{indexed} semantic patterns")
    {:ok, indexed}
  end

  @doc """
  Search for semantic patterns by natural language query

  Returns patterns ranked by similarity to the query.
  """
  @spec search(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def search(query, opts \\ []) do
    language = Keyword.get(opts, :language)
    top_k = Keyword.get(opts, :top_k, 5)

    Logger.debug("Searching patterns: #{query}")

    with {:ok, query_embedding} <- EmbeddingEngine.embed(query),
         {:ok, results} <- search_vector_db(query_embedding, language, top_k) do
      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generate code using the most relevant patterns

  Combines pattern search + RAG + code generation
  """
  @spec generate_with_patterns(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_with_patterns(task, opts) do
    language = Keyword.get(opts, :language, "elixir")

    with {:ok, patterns} <- search(task, language: language, top_k: 3),
         {:ok, code_examples} <- find_code_matching_patterns(patterns, language),
         {:ok, code} <- generate_code(task, patterns, code_examples, language) do
      {:ok, code}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  ## Private Functions

  defp load_all_templates do
    File.ls!(@templates_dir)
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.map(fn filename ->
      path = Path.join(@templates_dir, filename)

      case File.read(path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, template} -> template
            _ -> nil
          end

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_patterns(template) do
    language = template["language"]
    semantic = template["semantic_patterns"] || %{}

    common_patterns = semantic["common_patterns"] || []
    relationships = semantic["relationship_vectors"] || %{}
    architecture = semantic["architectural_hints"] || %{}

    # Extract from common_patterns array
    pattern_list =
      Enum.map(common_patterns, fn pattern ->
        %{
          id: generate_pattern_id(language, pattern["pattern"]),
          language: language,
          pattern_name: pattern["pattern"],
          pseudocode: pattern["pseudocode"],
          relationships: pattern["relationships"] || [],
          keywords: pattern["keywords"] || [],
          type: "common_pattern",
          searchable_text: build_searchable_text(pattern)
        }
      end)

    # Extract from relationship_vectors
    relationship_list =
      Enum.map(relationships, fn {key, value} ->
        %{
          id: generate_pattern_id(language, to_string(key)),
          language: language,
          pattern_name: to_string(key),
          pseudocode: value,
          relationships: [],
          keywords: extract_keywords_from_text(value),
          type: "relationship",
          searchable_text: "#{key}: #{value}"
        }
      end)

    # Extract from architectural_hints
    architecture_list =
      Enum.map(architecture, fn {key, value} ->
        %{
          id: generate_pattern_id(language, to_string(key)),
          language: language,
          pattern_name: to_string(key),
          pseudocode: value,
          relationships: [],
          keywords: extract_keywords_from_text(value),
          type: "architecture",
          searchable_text: "#{key}: #{value}"
        }
      end)

    pattern_list ++ relationship_list ++ architecture_list
  end

  defp build_searchable_text(pattern) do
    """
    #{pattern["pattern"]}
    #{pattern["pseudocode"]}
    #{Enum.join(pattern["relationships"] || [], " ")}
    #{Enum.join(pattern["keywords"] || [], " ")}
    """
    |> String.trim()
  end

  defp extract_keywords_from_text(text) do
    text
    |> String.split(~r/[\s→|,()]+/)
    |> Enum.map(&String.downcase/1)
    |> Enum.filter(&(String.length(&1) > 2))
    |> Enum.uniq()
  end

  defp generate_pattern_id(language, pattern_name) do
    "pattern_#{language}_#{pattern_name}"
    |> String.replace(~r/[^a-z0-9_]/, "_")
    |> String.downcase()
  end

  defp index_pattern(pattern) do
    # Generate embedding for the searchable text
    with {:ok, embedding} <- EmbeddingEngine.embed(pattern.searchable_text) do
      # Store in patterns table with embedding
      query = """
      INSERT INTO semantic_patterns (
        id, language, pattern_name, pseudocode,
        relationships, keywords, pattern_type,
        searchable_text, embedding, created_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
      ON CONFLICT (id) DO UPDATE SET
        pseudocode = $4,
        relationships = $5,
        keywords = $6,
        embedding = $9,
        updated_at = NOW()
      """

      params = [
        pattern.id,
        pattern.language,
        pattern.pattern_name,
        pattern.pseudocode,
        pattern.relationships,
        pattern.keywords,
        pattern.type,
        pattern.searchable_text,
        embedding
      ]

      case Repo.query(query, params) do
        {:ok, _} -> {:ok, pattern.id}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp search_vector_db(query_embedding, language, top_k) do
    query = """
    SELECT
      id,
      language,
      pattern_name,
      pseudocode,
      relationships,
      keywords,
      pattern_type,
      searchable_text,
      1 - (embedding <=> $1::vector) AS similarity
    FROM semantic_patterns
    #{if language, do: "WHERE language = $2", else: ""}
    ORDER BY embedding <=> $1::vector
    LIMIT $#{if language, do: "3", else: "2"}
    """

    params =
      if language do
        [query_embedding, language, top_k]
      else
        [query_embedding, top_k]
      end

    case Repo.query(query, params) do
      {:ok, %{rows: rows}} ->
        results =
          Enum.map(rows, fn row ->
            [id, lang, name, pseudo, rels, kw, type, text, sim] = row

            %{
              id: id,
              language: lang,
              pattern: name,
              pseudocode: pseudo,
              relationships: rels || [],
              keywords: kw || [],
              type: type,
              searchable_text: text,
              relevance: Float.round(sim, 3)
            }
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_code_matching_patterns(patterns, language) do
    # For each pattern, find actual code examples that match
    # This uses the pattern keywords to search the codebase_chunks table (YOUR code)

    keywords =
      patterns
      |> Enum.flat_map(& &1.keywords)
      |> Enum.uniq()
      # Top 10 keywords
      |> Enum.take(10)

    keyword_query = Enum.join(keywords, " OR ")

    query = """
    SELECT file_path, content, language
    FROM codebase_chunks
    WHERE language = $1
    AND (
      content ILIKE ANY(ARRAY[#{Enum.map_join(1..min(length(keywords), 5), ", ", fn i -> "$#{i + 1}" end)}])
    )
    ORDER BY similarity(content, $#{min(length(keywords), 5) + 2}) DESC
    LIMIT 5
    """

    search_patterns = Enum.take(keywords, 5) |> Enum.map(&"%#{&1}%")
    params = [language | search_patterns] ++ [keyword_query]

    case Repo.query(query, params) do
      {:ok, %{rows: rows}} ->
        examples =
          Enum.map(rows, fn [path, content, lang] ->
            %{path: path, content: String.slice(content, 0..500), language: lang}
          end)

        {:ok, examples}

      {:error, _} ->
        {:ok, []}
    end
  end

  defp generate_code(task, patterns, code_examples, language) do
    # Build prompt with patterns and examples
    patterns_text =
      patterns
      |> Enum.map(fn p ->
        """
        Pattern: #{p.pattern}
        Structure: #{p.pseudocode}
        Relationships: #{Enum.join(p.relationships, ", ")}
        """
      end)
      |> Enum.join("\n")

    examples_text =
      code_examples
      |> Enum.map(& &1.content)
      |> Enum.join("\n\n---\n\n")

    prompt = """
    Task: #{task}
    Language: #{language}

    ARCHITECTURAL PATTERNS (follow these structures):
    #{patterns_text}

    REAL CODE EXAMPLES (similar patterns from your codebase):
    #{examples_text}

    Generate code following the patterns above.
    OUTPUT CODE ONLY.
    """

    Singularity.CodeModel.complete(prompt, temperature: 0.05)
  end

  @doc """
  Create semantic_patterns table migration
  """
  def create_table_sql do
    """
    CREATE TABLE IF NOT EXISTS semantic_patterns (
      id TEXT PRIMARY KEY,
      language TEXT NOT NULL,
      pattern_name TEXT NOT NULL,
      pseudocode TEXT NOT NULL,
      relationships TEXT[] DEFAULT '{}',
      keywords TEXT[] DEFAULT '{}',
      pattern_type TEXT NOT NULL,
      searchable_text TEXT NOT NULL,
      embedding vector(768) NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS semantic_patterns_embedding_idx
      ON semantic_patterns USING hnsw (embedding vector_cosine_ops)
      WITH (m = 16, ef_construction = 64);

    CREATE INDEX IF NOT EXISTS semantic_patterns_language_idx
      ON semantic_patterns (language);

    CREATE INDEX IF NOT EXISTS semantic_patterns_keywords_idx
      ON semantic_patterns USING gin (keywords);
    """
  end
end
