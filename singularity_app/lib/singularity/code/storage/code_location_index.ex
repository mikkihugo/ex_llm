defmodule Singularity.CodeLocationIndex do
  @moduledoc """
  Index codebase files for fast pattern-based navigation.

  Answers:
  - "Where is X implemented?" → List of files
  - "What frameworks are used?" → List with files
  - "Where are NATS microservices?" → Filtered list
  - "What does this file do?" → Pattern summary
  """

  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias Singularity.Repo
  alias Singularity.{CodePatternExtractor, TechnologyDetector}

  schema "code_location_index" do
    field :filepath, :string
    field :patterns, {:array, :string}, default: []
    field :language, :string
    field :file_hash, :string
    field :lines_of_code, :integer

    # JSONB fields - dynamic data from tool_doc_index
    field :metadata, :map  # exports, imports, summary, etc.
    field :frameworks, :map  # detected frameworks from TechnologyDetector
    field :microservice, :map  # type, subjects, routes, etc.

    field :last_indexed, :utc_datetime

    timestamps()
  end

  def changeset(index, attrs) do
    index
    |> cast(attrs, [
      :filepath,
      :patterns,
      :language,
      :file_hash,
      :lines_of_code,
      :metadata,
      :frameworks,
      :microservice,
      :last_indexed
    ])
    |> validate_required([:filepath, :patterns, :language])
    |> unique_constraint(:filepath)
  end

  @doc """
  Index entire codebase.

  ## Examples

      iex> CodeLocationIndex.index_codebase(".")
      {:ok, %{indexed: 1523, skipped: 42, errors: 0}}
  """
  def index_codebase(path, opts \\ []) do
    concurrency = Keyword.get(opts, :concurrency, 10)

    files =
      Path.wildcard("#{path}/**/*.{ex,exs,gleam,rs,ts,js}")
      |> Enum.reject(&should_skip?/1)

    results =
      files
      |> Task.async_stream(&index_file/1, max_concurrency: concurrency, timeout: 30_000)
      |> Enum.reduce(%{indexed: 0, skipped: 0, errors: 0}, fn
        {:ok, :ok}, acc -> %{acc | indexed: acc.indexed + 1}
        {:ok, :skipped}, acc -> %{acc | skipped: acc.skipped + 1}
        {:ok, {:error, _}}, acc -> %{acc | errors: acc.errors + 1}
        {:exit, _}, acc -> %{acc | errors: acc.errors + 1}
      end)

    {:ok, results}
  end

  @doc """
  Index a single file.
  """
  def index_file(filepath) do
    with {:ok, code} <- File.read(filepath),
         language <- detect_language(filepath),
         patterns <- CodePatternExtractor.extract_from_code(code, language),
         file_hash <- compute_hash(code) do
      # Check if already indexed with same hash
      case Repo.get_by(__MODULE__, filepath: filepath) do
        %{file_hash: ^file_hash} ->
          :skipped

        existing ->
          # Build metadata from code
          metadata = %{
            exports: extract_exports(code, language),
            imports: extract_imports(code, language),
            summary: generate_summary(filepath, patterns)
          }

          # Detect frameworks using existing TechnologyDetector
          frameworks = detect_frameworks_from_tech_detector(filepath, patterns)

          # Classify microservice if applicable
          microservice = classify_microservice_type(code, patterns)

          attrs = %{
            filepath: filepath,
            patterns: patterns,
            language: to_string(language),
            file_hash: file_hash,
            lines_of_code: count_lines(code),
            metadata: metadata,
            frameworks: frameworks,
            microservice: microservice,
            last_indexed: DateTime.utc_now()
          }

          if existing do
            existing
            |> changeset(attrs)
            |> Repo.update()
          else
            %__MODULE__{}
            |> changeset(attrs)
            |> Repo.insert()
          end

          :ok
      end
    else
      {:error, _reason} -> {:error, :read_failed}
    end
  end

  @doc """
  Find files by pattern.

  ## Examples

      iex> CodeLocationIndex.find_pattern("genserver")
      ["lib/workers/user_worker.ex", "lib/services/email_service.ex"]
  """
  def find_pattern(pattern_keyword) do
    from(c in __MODULE__,
      where: fragment("? @> ARRAY[?]::text[]", c.patterns, ^pattern_keyword),
      select: c.filepath
    )
    |> Repo.all()
  end

  @doc """
  Find files by multiple patterns (AND logic).

  ## Examples

      iex> CodeLocationIndex.find_by_all_patterns(["genserver", "nats"])
      ["lib/services/nats_consumer.ex"]
  """
  def find_by_all_patterns(patterns) when is_list(patterns) do
    from(c in __MODULE__,
      where: fragment("? @> ARRAY[?]::text[]", c.patterns, ^patterns),
      select: c.filepath
    )
    |> Repo.all()
  end

  @doc """
  Find all microservices of a given type.

  ## Examples

      iex> CodeLocationIndex.find_microservices(:nats)
      [%{filepath: "...", patterns: [...], nats_subjects: [...]}]
  """
  def find_microservices(type \\ nil) do
    query =
      from c in __MODULE__,
        where: not is_nil(c.microservice_type),
        select: %{
          filepath: c.filepath,
          type: c.microservice_type,
          patterns: c.patterns,
          frameworks: c.frameworks,
          nats_subjects: c.nats_subjects,
          http_routes: c.http_routes
        }

    query =
      if type do
        where(query, [c], c.microservice_type == ^to_string(type))
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Find files using a specific framework.

  ## Examples

      iex> CodeLocationIndex.find_by_framework("Phoenix")
      ["lib/my_app_web/endpoint.ex", ...]
  """
  def find_by_framework(framework) do
    from(c in __MODULE__,
      where: fragment("? @> ARRAY[?]::text[]", c.frameworks, ^framework),
      select: %{filepath: c.filepath, patterns: c.patterns}
    )
    |> Repo.all()
  end

  @doc """
  Find NATS subscribers to a subject pattern.

  ## Examples

      iex> CodeLocationIndex.find_nats_subscribers("user.>")
      ["lib/services/user_service.ex", "lib/services/analytics.ex"]
  """
  def find_nats_subscribers(subject_pattern) do
    from(c in __MODULE__,
      where: fragment("? @> ARRAY[?]::text[]", c.nats_subjects, ^subject_pattern),
      select: c.filepath
    )
    |> Repo.all()
  end

  # Private functions

  defp should_skip?(path) do
    String.contains?(path, ["_build", "deps", "node_modules", ".git", "test"])
  end

  defp detect_language(filepath) do
    case Path.extname(filepath) do
      ".ex" -> :elixir
      ".exs" -> :elixir
      ".gleam" -> :gleam
      ".rs" -> :rust
      ".ts" -> :typescript
      ".js" -> :javascript
      _ -> :unknown
    end
  end

  defp extract_exports(code, :elixir) do
    # Extract public functions: def name(
    Regex.scan(~r/def\s+(\w+)\s*\(/, code)
    |> Enum.map(fn [_, name] -> name end)
  end

  defp extract_exports(_code, _language), do: []

  defp extract_imports(code, :elixir) do
    # Extract alias/import statements
    alias_imports = Regex.scan(~r/alias\s+([\w.]+)/, code) |> Enum.map(fn [_, mod] -> mod end)
    import_imports = Regex.scan(~r/import\s+([\w.]+)/, code) |> Enum.map(fn [_, mod] -> mod end)

    (alias_imports ++ import_imports) |> Enum.uniq()
  end

  defp extract_imports(_code, _language), do: []

  defp generate_summary(filepath, patterns) do
    filename = Path.basename(filepath, Path.extname(filepath))

    # Extract domain from patterns
    domain_words = Enum.filter(patterns, &String.match?(&1, ~r/^[a-z]+$/))

    top_patterns = Enum.take(patterns, 3)

    "#{filename}: #{Enum.join(top_patterns, ", ")}"
  end

  defp count_lines(code), do: String.split(code, "\n") |> length()

  defp compute_hash(code) do
    :crypto.hash(:sha256, code) |> Base.encode16(case: :lower)
  end

  defp detect_frameworks_from_tech_detector(filepath, patterns) do
    # Use existing TechnologyDetector
    codebase_dir = Path.dirname(filepath)

    case TechnologyDetector.detect_technologies_elixir(codebase_dir, analysis: %{patterns: patterns}) do
      {:ok, %{technologies: tech}} ->
        %{
          detected: Map.get(tech, :frameworks, []),
          languages: Map.get(tech, :languages, []),
          databases: Map.get(tech, :databases, []),
          messaging: Map.get(tech, :messaging, [])
        }

      _ ->
        # Fallback to pattern-based detection
        %{detected: simple_framework_detection(patterns)}
    end
  end

  defp simple_framework_detection(patterns) do
    # Quick pattern-based fallback
    mapping = [
      {["phoenix"], "Phoenix"},
      {["broadway"], "Broadway"},
      {["nats", "gnat"], "NATS"},
      {["ecto"], "Ecto"},
      {["genserver"], "GenServer"}
    ]

    Enum.filter(mapping, fn {keywords, _name} ->
      Enum.any?(keywords, &(&1 in patterns))
    end)
    |> Enum.map(fn {_keywords, name} -> name end)
  end

  defp classify_microservice_type(code, patterns) do
    type =
      cond do
        "nats" in patterns and "genserver" in patterns -> "nats_microservice"
        "broadway" in patterns -> "stream_processor"
        "channel" in patterns -> "websocket_service"
        "plug" in patterns and "http" in patterns -> "http_api"
        "genserver" in patterns -> "otp_service"
        true -> nil
      end

    if type do
      %{
        type: type,
        nats_subjects: extract_nats_subjects(code),
        http_routes: extract_http_routes(code)
      }
    else
      nil
    end
  end

  defp extract_nats_subjects(code) do
    # Extract NATS subject patterns: Gnat.sub(conn, self(), "subject")
    Regex.scan(~r/Gnat\.sub\([^,]+,[^,]+,\s*"([^"]+)"/, code)
    |> Enum.map(fn [_, subject] -> subject end)
  end

  defp extract_http_routes(code) do
    # Extract routes: get "/users", ...
    Regex.scan(~r/(get|post|put|patch|delete)\s+"([^"]+)"/, code)
    |> Enum.map(fn [_, method, path] -> %{method: method, path: path} end)
  end
end
