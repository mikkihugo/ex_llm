defmodule Singularity.Code.Analyzers.MicroserviceAnalyzer do
  @moduledoc """
  Lightweight microservice analyzer implemented in Elixir.

  The original Rust-backed analyzer is unavailable in this trimmed workspace, so this module
  provides heuristic discovery of service boundaries directly in Elixir. It inspects the
  repository layout and common build files to infer the presence of TypeScript, Rust, Python,
  and Go services.

  ## Uses

  - `Singularity.LanguageDetection` - Authoritative language detection via Rust parser registry
  """

  require Logger
  alias Singularity.CodeAnalysis.LanguageDetection

  @service_root_candidates ["apps", "services", "packages", "apps/services", "services/apps"]

  @doc """
  Analyze TypeScript-oriented services under the given codebase path.
  """
  def analyze_typescript_service(codebase_path) do
    codebase_path
    |> discover_services()
    |> Enum.filter(&(&1.language == "typescript"))
  end

  @doc """
  Analyze Rust-oriented services under the given codebase path.
  """
  def analyze_rust_service(codebase_path) do
    codebase_path
    |> discover_services()
    |> Enum.filter(&(&1.language == "rust"))
  end

  @doc """
  Analyze Python-oriented services under the given codebase path.
  """
  def analyze_python_service(codebase_path) do
    codebase_path
    |> discover_services()
    |> Enum.filter(&(&1.language == "python"))
  end

  @doc """
  Analyze Go-oriented services under the given codebase path.
  """
  def analyze_go_service(codebase_path) do
    codebase_path
    |> discover_services()
    |> Enum.filter(&(&1.language == "go"))
  end

  @doc """
  Analyze all supported services and return a map keyed by language.
  """
  def analyze_services(codebase_path) do
    services = discover_services(codebase_path)

    %{
      typescript: Enum.filter(services, &(&1.language == "typescript")),
      rust: Enum.filter(services, &(&1.language == "rust")),
      python: Enum.filter(services, &(&1.language == "python")),
      go: Enum.filter(services, &(&1.language == "go"))
    }
  end

  @doc """
  Detect the overall completion status for a discovery event.

  Falls back to heuristic inference based on the files included in the discovery payload.
  """
  def detect_completion_status(discovery) do
    services =
      case Map.get(discovery, :path) do
        path when is_binary(path) ->
          if File.dir?(path),
            do: discover_services(path),
            else: infer_services_from_files(Map.get(discovery, :source_files, []))

        _ ->
          infer_services_from_files(Map.get(discovery, :source_files, []))
      end

    service_count = length(services)

    status =
      cond do
        service_count >= 4 -> :microservices
        service_count >= 2 -> :distributed
        service_count == 1 -> :modular
        true -> :monolith
      end

    %{
      status: status,
      service_count: service_count,
      services: services
    }
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp discover_services(codebase_path) when is_binary(codebase_path) do
    codebase_path
    |> expand_candidates()
    |> Enum.flat_map(&collect_service_dirs/1)
    |> Enum.map(&build_service_info/1)
    |> Enum.reject(&is_nil/1)
  end

  defp discover_services(_), do: []

  defp expand_candidates(codebase_path) do
    Enum.map(@service_root_candidates, &Path.join(codebase_path, &1))
  end

  defp collect_service_dirs(root) do
    case File.ls(root) do
      {:ok, entries} ->
        entries
        |> Enum.map(&Path.join(root, &1))
        |> Enum.filter(&File.dir?/1)

      {:error, _} ->
        []
    end
  end

  defp build_service_info(service_path) do
    language = detect_language(service_path)

    if language do
      framework = detect_framework(service_path, language)
      entrypoint = detect_entrypoint(service_path, language)

      %{
        name: Path.basename(service_path),
        language: language,
        framework: framework,
        entrypoint: entrypoint,
        root: service_path
      }
    end
  rescue
    error ->
      Logger.debug("Skipping service candidate #{service_path}: #{inspect(error)}")
      nil
  end

  defp detect_language(service_path) do
    # Use authoritative LanguageDetection (Rust parser registry)
    case LanguageDetection.detect(service_path) do
      {:ok, atom} when is_atom(atom) -> atom_to_string(atom)
      {:error, _} -> nil
    end
  end

  # Convert atoms from LanguageDetector to strings for compatibility
  defp atom_to_string(atom) do
    atom |> Atom.to_string()
  end

  defp detect_framework(service_path, "typescript") do
    cond do
      File.exists?(Path.join(service_path, "nest-cli.json")) -> "nestjs"
      File.exists?(Path.join(service_path, "angular.json")) -> "angular"
      File.exists?(Path.join(service_path, "next.config.js")) -> "nextjs"
      File.exists?(Path.join(service_path, "package.json")) -> "node"
      true -> nil
    end
  end

  defp detect_framework(service_path, "python") do
    cond do
      has_requirement?(service_path, "fastapi") -> "fastapi"
      has_requirement?(service_path, "django") -> "django"
      has_requirement?(service_path, "flask") -> "flask"
      true -> nil
    end
  end

  defp detect_framework(service_path, "rust") do
    cond do
      File.exists?(Path.join(service_path, "Cargo.toml")) &&
          File.exists?(Path.join(service_path, "src/main.rs")) ->
        "actix"

      true ->
        nil
    end
  end

  defp detect_framework(_service_path, _language), do: nil

  defp detect_entrypoint(service_path, "typescript") do
    cond do
      File.exists?(Path.join(service_path, "src/main.ts")) -> "src/main.ts"
      File.exists?(Path.join(service_path, "src/index.ts")) -> "src/index.ts"
      true -> nil
    end
  end

  defp detect_entrypoint(service_path, "python") do
    candidates = ["app.py", "main.py", "manage.py"]

    Enum.find_value(candidates, fn file ->
      path = Path.join(service_path, file)
      if File.exists?(path), do: file
    end)
  end

  defp detect_entrypoint(service_path, "rust") do
    if File.exists?(Path.join(service_path, "src/main.rs")), do: "src/main.rs"
  end

  defp detect_entrypoint(service_path, "go") do
    case Path.wildcard(Path.join(service_path, "cmd/*/main.go")) do
      [first | _] -> Path.relative_to(first, service_path)
      _ -> nil
    end
  end

  defp detect_entrypoint(_service_path, _language), do: nil

  defp ts_sources?(service_path) do
    Path.wildcard(Path.join(service_path, "**/*.ts")) |> Enum.any?()
  end

  defp has_requirement?(service_path, dependency) do
    requirements_path = Path.join(service_path, "requirements.txt")

    cond do
      File.exists?(requirements_path) ->
        requirements_path
        |> File.read()
        |> case do
          {:ok, contents} -> String.contains?(String.downcase(contents), dependency)
          _ -> false
        end

      File.exists?(Path.join(service_path, "pyproject.toml")) ->
        service_path
        |> Path.join("pyproject.toml")
        |> File.read()
        |> case do
          {:ok, contents} -> String.contains?(String.downcase(contents), dependency)
          _ -> false
        end

      true ->
        false
    end
  end

  defp infer_services_from_files(files) do
    files
    |> Enum.map(&String.split(&1, ["/", "\\"], trim: true))
    |> Enum.filter(&(&1 != []))
    |> Enum.map(fn segments ->
      Enum.find(segments, &service_segment?/1)
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn name ->
      %{name: name, language: nil, framework: nil, entrypoint: nil, root: nil}
    end)
  end

  defp service_segment?(segment) do
    down = String.downcase(segment)
    String.contains?(down, "service") || down in ~w(apps services packages)
  end
end
