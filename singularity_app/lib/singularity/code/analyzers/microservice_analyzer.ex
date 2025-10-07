defmodule Singularity.CodeAnalysis.MicroserviceAnalyzer do
  @moduledoc """
  Analyzes microservices (TypeScript, Rust, Python, Go) in singularity-engine to understand their structure,
  dependencies, completion status, and implementation needs.
  """

  require Logger

  @doc "Analyze a TypeScript/NestJS service"
  def analyze_typescript_service(service_path) do
    Logger.info("Analyzing TypeScript service: #{service_path}")

    with {:ok, package_json} <- read_package_json(service_path),
         {:ok, project_json} <- read_project_json(service_path),
         {:ok, source_files} <- scan_source_files(service_path),
         {:ok, dependencies} <- analyze_dependencies(service_path) do
      %{
        service_type: :nestjs,
        language: :typescript,
        path: service_path,
        package_info: package_json,
        project_config: project_json,
        source_files: source_files,
        dependencies: dependencies,
        completion_status: calculate_completion_status(source_files),
        analysis_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to analyze TypeScript service: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Analyze a Rust service"
  def analyze_rust_service(service_path) do
    Logger.info("Analyzing Rust service: #{service_path}")

    with {:ok, cargo_toml} <- read_cargo_toml(service_path),
         {:ok, source_files} <- scan_rust_files(service_path),
         {:ok, dependencies} <- analyze_cargo_dependencies(cargo_toml) do
      %{
        service_type: :rust,
        language: :rust,
        path: service_path,
        cargo_info: cargo_toml,
        source_files: source_files,
        dependencies: dependencies,
        completion_status: calculate_rust_completion(source_files),
        analysis_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to analyze Rust service: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Analyze a Python service"
  def analyze_python_service(service_path) do
    Logger.info("Analyzing Python service: #{service_path}")

    with {:ok, requirements_txt} <- read_requirements_txt(service_path),
         {:ok, source_files} <- scan_python_files(service_path),
         {:ok, dependencies} <- analyze_python_dependencies(requirements_txt) do
      %{
        service_type: :fastapi,
        language: :python,
        path: service_path,
        requirements: requirements_txt,
        source_files: source_files,
        dependencies: dependencies,
        completion_status: calculate_python_completion(source_files),
        analysis_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to analyze Python service: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Analyze a Go service"
  def analyze_go_service(service_path) do
    Logger.info("Analyzing Go service: #{service_path}")

    with {:ok, go_mod} <- read_go_mod(service_path),
         {:ok, source_files} <- scan_go_files(service_path),
         {:ok, dependencies} <- analyze_go_dependencies(go_mod) do
      %{
        service_type: :go_service,
        language: :go,
        path: service_path,
        go_mod_info: go_mod,
        source_files: source_files,
        dependencies: dependencies,
        completion_status: calculate_go_completion(source_files),
        analysis_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to analyze Go service: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Detect completion status of a service"
  def detect_completion_status(service_data) do
    source_files = service_data.source_files || []

    total_files = length(source_files)
    completed_files = Enum.count(source_files, &is_file_complete?/1)

    completion_percentage =
      if total_files > 0 do
        completed_files / total_files * 100
      else
        0.0
      end

    %{
      total_files: total_files,
      completed_files: completed_files,
      completion_percentage: Float.round(completion_percentage, 2),
      status: determine_status(completion_percentage),
      missing_components: detect_missing_components(service_data)
    }
  end

  ## Private Functions

  defp read_package_json(service_path) do
    package_path = Path.join(service_path, "package.json")

    case File.read(package_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, json} -> {:ok, json}
          {:error, _} -> {:error, :invalid_json}
        end

      {:error, _} ->
        {:error, :file_not_found}
    end
  end

  defp read_project_json(service_path) do
    project_path = Path.join(service_path, "project.json")

    case File.read(project_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, json} -> {:ok, json}
          {:error, _} -> {:error, :invalid_json}
        end

      {:error, _} ->
        {:error, :file_not_found}
    end
  end

  defp read_cargo_toml(service_path) do
    cargo_path = Path.join(service_path, "Cargo.toml")

    case File.read(cargo_path) do
      {:ok, content} -> {:ok, parse_toml(content)}
      {:error, _} -> {:error, :file_not_found}
    end
  end

  defp read_requirements_txt(service_path) do
    req_path = Path.join(service_path, "requirements.txt")

    case File.read(req_path) do
      {:ok, content} -> {:ok, String.split(content, "\n") |> Enum.reject(&(&1 == ""))}
      {:error, _} -> {:error, :file_not_found}
    end
  end

  defp read_go_mod(service_path) do
    go_mod_path = Path.join(service_path, "go.mod")

    case File.read(go_mod_path) do
      {:ok, content} -> {:ok, parse_go_mod(content)}
      {:error, _} -> {:error, :file_not_found}
    end
  end

  defp scan_source_files(service_path) do
    src_path = Path.join(service_path, "src")

    if File.exists?(src_path) do
      files =
        Path.wildcard(Path.join(src_path, "**/*.ts"))
        |> Enum.map(&%{path: &1, type: :typescript, size: get_file_size(&1)})

      {:ok, files}
    else
      {:ok, []}
    end
  end

  defp scan_rust_files(service_path) do
    src_path = Path.join(service_path, "src")

    if File.exists?(src_path) do
      files =
        Path.wildcard(Path.join(src_path, "**/*.rs"))
        |> Enum.map(&%{path: &1, type: :rust, size: get_file_size(&1)})

      {:ok, files}
    else
      {:ok, []}
    end
  end

  defp scan_python_files(service_path) do
    files =
      Path.wildcard(Path.join(service_path, "**/*.py"))
      |> Enum.map(&%{path: &1, type: :python, size: get_file_size(&1)})

    {:ok, files}
  end

  defp scan_go_files(service_path) do
    files =
      Path.wildcard(Path.join(service_path, "**/*.go"))
      |> Enum.map(&%{path: &1, type: :go, size: get_file_size(&1)})

    {:ok, files}
  end

  defp get_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size}} -> size
      {:error, _} -> 0
    end
  end

  defp analyze_dependencies(service_path) do
    # Analyze package.json dependencies
    {:ok, package_json} = read_package_json(service_path)
    dependencies = Map.get(package_json, "dependencies", %{})
    dev_dependencies = Map.get(package_json, "devDependencies", %{})

    {:ok,
     %{
       runtime: dependencies,
       development: dev_dependencies,
       total_count: map_size(dependencies) + map_size(dev_dependencies)
     }}
  end

  defp analyze_cargo_dependencies(cargo_toml) do
    dependencies = Map.get(cargo_toml, "dependencies", %{})
    dev_dependencies = Map.get(cargo_toml, "dev-dependencies", %{})

    {:ok,
     %{
       runtime: dependencies,
       development: dev_dependencies,
       total_count: map_size(dependencies) + map_size(dev_dependencies)
     }}
  end

  defp analyze_python_dependencies(requirements) do
    {:ok,
     %{
       packages: requirements,
       total_count: length(requirements)
     }}
  end

  defp analyze_go_dependencies(go_mod) do
    require_deps = Map.get(go_mod, "require", [])

    {:ok,
     %{
       packages: require_deps,
       total_count: length(require_deps)
     }}
  end

  defp calculate_completion_status(source_files) do
    total_files = length(source_files)

    if total_files == 0 do
      0.0
    else
      # Simple heuristic: files with substantial content are "complete"
      completed =
        Enum.count(source_files, fn file ->
          # Files larger than 1KB are considered substantial
          file.size > 1000
        end)

      completed / total_files * 100
    end
  end

  defp calculate_rust_completion(source_files) do
    calculate_completion_status(source_files)
  end

  defp calculate_python_completion(source_files) do
    calculate_completion_status(source_files)
  end

  defp calculate_go_completion(source_files) do
    calculate_completion_status(source_files)
  end

  defp is_file_complete?(file) do
    file.size > 1000 and not String.contains?(file.path, "test")
  end

  defp determine_status(completion_percentage) do
    cond do
      completion_percentage >= 90 -> :complete
      completion_percentage >= 70 -> :mostly_complete
      completion_percentage >= 30 -> :in_progress
      completion_percentage > 0 -> :started
      true -> :empty
    end
  end

  defp detect_missing_components(service_data) do
    missing = []

    # Check for common missing files
    service_path = service_data.path

    missing =
      if not File.exists?(Path.join(service_path, "README.md")),
        do: ["README.md" | missing],
        else: missing

    missing =
      if not File.exists?(Path.join(service_path, "Dockerfile")),
        do: ["Dockerfile" | missing],
        else: missing

    missing =
      if not File.exists?(Path.join(service_path, "tests")),
        do: ["tests" | missing],
        else: missing

    missing
  end

  defp parse_toml(content) do
    # Simple TOML parsing - extract key information
    lines = String.split(content, "\n")

    dependencies = extract_toml_section(lines, "dependencies")
    dev_dependencies = extract_toml_section(lines, "dev-dependencies")

    %{
      "dependencies" => dependencies,
      "dev-dependencies" => dev_dependencies,
      "total_deps" => length(dependencies) + length(dev_dependencies),
      "has_rust_deps" => has_rust_dependencies?(dependencies)
    }
  end

  defp extract_toml_section(lines, section_name) do
    in_section = false
    deps = []

    {_, deps} =
      Enum.reduce(lines, {in_section, deps}, fn line, {in_section, deps} ->
        cond do
          String.trim(line) == "[#{section_name}]" ->
            {true, deps}

          in_section && String.starts_with?(String.trim(line), "[") ->
            {false, deps}

          in_section && String.contains?(line, "=") ->
            [name | _] = String.split(line, "=")
            clean_name = String.trim(name)
            {in_section, [clean_name | deps]}

          true ->
            {in_section, deps}
        end
      end)

    Enum.reverse(deps)
  end

  defp has_rust_dependencies?(deps) do
    rust_crates = ["serde", "tokio", "axum", "sqlx", "uuid", "chrono", "anyhow"]
    Enum.any?(deps, fn dep -> dep in rust_crates end)
  end

  defp parse_go_mod(content) do
    # Simple go.mod parsing - extract module information
    lines = String.split(content, "\n")

    module_name = extract_module_name(lines)
    go_version = extract_go_version(lines)
    requires = extract_requires(lines)

    %{
      "module" => module_name,
      "go_version" => go_version,
      "require" => requires,
      "total_deps" => length(requires),
      "has_standard_libs" => has_standard_libraries?(requires)
    }
  end

  defp extract_module_name(lines) do
    case Enum.find(lines, fn line -> String.starts_with?(String.trim(line), "module ") end) do
      nil ->
        "unknown"

      line ->
        [_, name] = String.split(line, " ", parts: 2)
        String.trim(name)
    end
  end

  defp extract_go_version(lines) do
    case Enum.find(lines, fn line -> String.starts_with?(String.trim(line), "go ") end) do
      nil ->
        "unknown"

      line ->
        [_, version] = String.split(line, " ", parts: 2)
        String.trim(version)
    end
  end

  defp extract_requires(lines) do
    in_require_section = false
    requires = []

    {_, requires} =
      Enum.reduce(lines, {in_require_section, requires}, fn line, {in_section, reqs} ->
        cond do
          String.trim(line) == "require (" ->
            {true, reqs}

          in_section && String.trim(line) == ")" ->
            {false, reqs}

          in_section && String.contains?(line, " ") ->
            [name | _] = String.split(line, " ")
            clean_name = String.trim(name)
            {in_section, [clean_name | reqs]}

          true ->
            {in_section, reqs}
        end
      end)

    Enum.reverse(requires)
  end

  defp has_standard_libraries?(requires) do
    std_libs = ["fmt", "net/http", "encoding/json", "os", "io", "strings", "time"]
    Enum.any?(requires, fn req -> req in std_libs end)
  end
end
