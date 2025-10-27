defmodule Singularity.Storage.Code.CodeLocationIndexService do
  @moduledoc """
  Service for indexing and querying codebase locations.

  Provides operations for:
  - Indexing entire codebase or individual files
  - Finding files by pattern, framework, or microservice type
  - Extracting and classifying code metadata
  - Fast pattern-based code navigation
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.CodeLocationIndex
  alias Singularity.CodePatternExtractor

  require Logger

  @doc """
  Index entire codebase.

  ## Examples

      iex> CodeLocationIndexService.index_codebase(".")
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
      case Repo.get_by(CodeLocationIndex, filepath: filepath) do
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
            |> CodeLocationIndex.changeset(attrs)
            |> Repo.update()
          else
            %CodeLocationIndex{}
            |> CodeLocationIndex.changeset(attrs)
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

      iex> CodeLocationIndexService.find_pattern("genserver")
      ["lib/workers/user_worker.ex", "lib/services/email_service.ex"]
  """
  def find_pattern(pattern_keyword) do
    from(c in CodeLocationIndex,
      where: fragment("? @> ARRAY[?]::text[]", c.patterns, ^pattern_keyword),
      select: c.filepath
    )
    |> Repo.all()
  end

  @doc """
  Find files by multiple patterns (AND logic).

  ## Examples

      iex> CodeLocationIndexService.find_by_all_patterns(["genserver", "messaging"])
      ["lib/services/message_consumer.ex"]
  """
  def find_by_all_patterns(patterns) when is_list(patterns) do
    from(c in CodeLocationIndex,
      where: fragment("? @> ARRAY[?]::text[]", c.patterns, ^patterns),
      select: c.filepath
    )
    |> Repo.all()
  end

  @doc """
  Find all microservices of a given type.

  ## Examples

      iex> CodeLocationIndexService.find_microservices(:pgmq)
      [%{filepath: "...", patterns: [...], pgmq_subjects: [...]}]
  """
  def find_microservices(type \\ nil) do
    query =
      from c in CodeLocationIndex,
        where: not is_nil(c.microservice_type),
        select: %{
          filepath: c.filepath,
          type: c.microservice_type,
          patterns: c.patterns,
          frameworks: c.frameworks,
          pgmq_subjects: c.pgmq_subjects,
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

      iex> CodeLocationIndexService.find_by_framework("Phoenix")
      ["lib/my_app_web/endpoint.ex", ...]
  """
  def find_by_framework(framework) do
    from(c in CodeLocationIndex,
      where: fragment("? @> ARRAY[?]::text[]", c.frameworks, ^framework),
      select: %{filepath: c.filepath, patterns: c.patterns}
    )
    |> Repo.all()
  end

  @doc """
  Find pgmq subscribers to a subject pattern.

  ## Examples

      iex> CodeLocationIndexService.find_pgmq_subscribers("user.>")
      ["lib/services/user_service.ex", "lib/services/analytics.ex"]
  """
  def find_pgmq_subscribers(subject_pattern) do
    from(c in CodeLocationIndex,
      where: fragment("? @> ARRAY[?]::text[]", c.pgmq_subjects, ^subject_pattern),
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

  defp extract_exports(code, language) do
    case language do
      :elixir ->
        extract_elixir_exports(code)

      :javascript ->
        extract_javascript_exports(code)

      :typescript ->
        extract_typescript_exports(code)

      :rust ->
        extract_rust_exports(code)

      _ ->
        []
    end
  end

  defp extract_imports(code, language) do
    case language do
      :elixir ->
        extract_elixir_imports(code)

      :javascript ->
        extract_javascript_imports(code)

      :typescript ->
        extract_typescript_imports(code)

      :rust ->
        extract_rust_imports(code)

      _ ->
        []
    end
  end

  defp extract_elixir_exports(code) do
    # Extract public functions (def, defp is private)
    Regex.scan(~r/def\s+(\w+)\s*\(/, code)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
  end

  defp extract_elixir_imports(code) do
    alias_imports = Regex.scan(~r/alias\s+([\w.]+)/, code) |> Enum.map(fn [_, mod] -> mod end)
    import_imports = Regex.scan(~r/import\s+([\w.]+)/, code) |> Enum.map(fn [_, mod] -> mod end)
    require_imports = Regex.scan(~r/require\s+([\w.]+)/, code) |> Enum.map(fn [_, mod] -> mod end)

    (alias_imports ++ import_imports ++ require_imports) |> Enum.uniq()
  end

  defp extract_javascript_exports(code) do
    # Extract exports (export function, export const, export default)
    export_functions =
      Regex.scan(~r/export\s+function\s+(\w+)/, code) |> Enum.map(fn [_, name] -> name end)

    export_constants =
      Regex.scan(~r/export\s+const\s+(\w+)/, code) |> Enum.map(fn [_, name] -> name end)

    export_defaults =
      Regex.scan(~r/export\s+default\s+(\w+)/, code) |> Enum.map(fn [_, name] -> name end)

    (export_functions ++ export_constants ++ export_defaults) |> Enum.uniq()
  end

  defp extract_javascript_imports(code) do
    # Extract imports (import ... from, import { ... } from)
    named_imports =
      Regex.scan(~r/import\s+\{([^}]+)\}\s+from\s+['"]([^'"]+)['"]/, code)
      |> Enum.map(fn [_, names, module] ->
        names |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.map(&{&1, module})
      end)
      |> List.flatten()

    default_imports =
      Regex.scan(~r/import\s+(\w+)\s+from\s+['"]([^'"]+)['"]/, code)
      |> Enum.map(fn [_, name, module] -> {name, module} end)

    (named_imports ++ default_imports) |> Enum.uniq()
  end

  defp extract_typescript_exports(code) do
    # Similar to JavaScript but with type exports
    export_functions =
      Regex.scan(~r/export\s+function\s+(\w+)/, code) |> Enum.map(fn [_, name] -> name end)

    export_constants =
      Regex.scan(~r/export\s+const\s+(\w+)/, code) |> Enum.map(fn [_, name] -> name end)

    export_types =
      Regex.scan(~r/export\s+type\s+(\w+)/, code) |> Enum.map(fn [_, name] -> name end)

    export_interfaces =
      Regex.scan(~r/export\s+interface\s+(\w+)/, code) |> Enum.map(fn [_, name] -> name end)

    (export_functions ++ export_constants ++ export_types ++ export_interfaces) |> Enum.uniq()
  end

  defp extract_typescript_imports(code) do
    # Similar to JavaScript but with type imports
    named_imports =
      Regex.scan(~r/import\s+\{([^}]+)\}\s+from\s+['"]([^'"]+)['"]/, code)
      |> Enum.map(fn [_, names, module] ->
        names |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.map(&{&1, module})
      end)
      |> List.flatten()

    default_imports =
      Regex.scan(~r/import\s+(\w+)\s+from\s+['"]([^'"]+)['"]/, code)
      |> Enum.map(fn [_, name, module] -> {name, module} end)

    type_imports =
      Regex.scan(~r/import\s+type\s+\{([^}]+)\}\s+from\s+['"]([^'"]+)['"]/, code)
      |> Enum.map(fn [_, names, module] ->
        names |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.map(&{&1, module})
      end)
      |> List.flatten()

    (named_imports ++ default_imports ++ type_imports) |> Enum.uniq()
  end

  defp extract_rust_exports(code) do
    # Extract public functions and structs
    pub_functions = Regex.scan(~r/pub\s+fn\s+(\w+)/, code) |> Enum.map(fn [_, name] -> name end)
    pub_structs = Regex.scan(~r/pub\s+struct\s+(\w+)/, code) |> Enum.map(fn [_, name] -> name end)
    pub_enums = Regex.scan(~r/pub\s+enum\s+(\w+)/, code) |> Enum.map(fn [_, name] -> name end)

    (pub_functions ++ pub_structs ++ pub_enums) |> Enum.uniq()
  end

  defp extract_rust_imports(code) do
    # Extract use statements
    use_statements =
      Regex.scan(~r/use\s+([\w:]+)/, code) |> Enum.map(fn [_, module] -> module end)

    use_crate_statements =
      Regex.scan(~r/use\s+crate::([\w:]+)/, code)
      |> Enum.map(fn [_, module] -> "crate::#{module}" end)

    (use_statements ++ use_crate_statements) |> Enum.uniq()
  end

  defp generate_summary(filepath, patterns) do
    filename = Path.basename(filepath, Path.extname(filepath))

    # Extract domain from patterns
    _domain_words = Enum.filter(patterns, &String.match?(&1, ~r/^[a-z]+$/))

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

    case TechnologyDetector.detect_technologies_elixir(codebase_dir,
           analysis: %{patterns: patterns}
         ) do
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
      {["pgmq", "gnat"], "pgmq"},
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
        "messaging" in patterns and "genserver" in patterns -> "messaging_microservice"
        "broadway" in patterns -> "stream_processor"
        "channel" in patterns -> "websocket_service"
        "plug" in patterns and "http" in patterns -> "http_api"
        "genserver" in patterns -> "otp_service"
        true -> nil
      end

    if type do
      %{
        type: type,
        pgmq_subjects: extract_pgmq_subjects(code),
        http_routes: extract_http_routes(code)
      }
    else
      nil
    end
  end

  defp extract_pgmq_subjects(code) do
    # Extract pgmq subject patterns: Singularity.Jobs.PgmqClient.sub(conn, self(), "subject")
    Regex.scan(~r/pgmq\.sub\([^,]+,[^,]+,\s*"([^"]+)"/, code)
    |> Enum.map(fn [_, subject] -> subject end)
  end

  defp extract_http_routes(code) do
    # Extract routes: get "/users", ...
    Regex.scan(~r/(get|post|put|patch|delete)\s+"([^"]+)"/, code)
    |> Enum.map(fn [_, method, path] -> %{method: method, path: path} end)
  end
end
