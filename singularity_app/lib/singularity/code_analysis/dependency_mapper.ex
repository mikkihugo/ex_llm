defmodule Singularity.CodeAnalysis.DependencyMapper do
  @moduledoc """
  Maps service relationships and dependencies in singularity-engine to understand
  the architecture and identify consolidation opportunities.
  """

  require Logger

  alias Singularity.Engine.CodebaseStore

  @doc "Map all service dependencies across the platform"
  def map_service_dependencies do
    Logger.info("Mapping service dependencies across singularity-engine")

    with {:ok, services} <- load_all_services(),
         {:ok, dependencies} <- analyze_all_dependencies(services),
         {:ok, relationships} <- build_dependency_graph(dependencies) do
      %{
        total_services: length(services),
        total_dependencies: count_dependencies(dependencies),
        dependency_graph: relationships,
        circular_dependencies: detect_circular_dependencies(relationships),
        consolidation_candidates: find_consolidation_candidates(relationships),
        analysis_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to map service dependencies: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Detect circular dependencies between services"
  def detect_circular_dependencies(dependency_graph) do
    Logger.info("Detecting circular dependencies")

    services = Map.keys(dependency_graph)

    Enum.flat_map(services, fn service ->
      find_cycles_from_service(service, dependency_graph, [])
    end)
    |> Enum.uniq()
  end

  @doc "Find services that can be consolidated"
  def find_consolidation_candidates(dependency_graph) do
    Logger.info("Finding consolidation candidates")

    # Group services by domain
    domain_groups = group_services_by_domain(dependency_graph)

    # Find services with high coupling
    high_coupling = find_high_coupling_services(dependency_graph)

    # Find duplicate services
    duplicates = find_duplicate_services(dependency_graph)

    %{
      domain_groups: domain_groups,
      high_coupling: high_coupling,
      duplicates: duplicates,
      consolidation_plan: generate_consolidation_plan(domain_groups, high_coupling, duplicates)
    }
  end

  @doc "Analyze service coupling metrics"
  def analyze_service_coupling(service_name, dependency_graph) do
    incoming = count_incoming_dependencies(service_name, dependency_graph)
    outgoing = count_outgoing_dependencies(service_name, dependency_graph)

    coupling_score = (incoming + outgoing) / 2

    %{
      service: service_name,
      incoming_dependencies: incoming,
      outgoing_dependencies: outgoing,
      coupling_score: coupling_score,
      coupling_level: determine_coupling_level(coupling_score)
    }
  end

  ## Private Functions

  defp load_all_services do
    # Load all services from the database
    services = CodebaseStore.all_services()
    {:ok, services}
  end

  defp analyze_all_dependencies(services) do
    dependencies =
      Enum.flat_map(services, fn service ->
        analyze_service_dependencies(service)
      end)

    {:ok, dependencies}
  end

  defp analyze_service_dependencies(service) do
    service_path = service.path

    dependencies =
      case service.language do
        :typescript -> analyze_typescript_dependencies(service_path)
        :rust -> analyze_rust_dependencies(service_path)
        :python -> analyze_python_dependencies(service_path)
        :go -> analyze_go_dependencies(service_path)
        _ -> []
      end

    Enum.map(dependencies, fn dep ->
      %{
        source_service: service.service_name,
        target_service: dep.target,
        dependency_type: dep.type,
        file_path: dep.file_path,
        line_number: dep.line_number
      }
    end)
  end

  defp analyze_typescript_dependencies(service_path) do
    # Scan TypeScript files for imports
    src_path = Path.join(service_path, "src")

    if File.exists?(src_path) do
      Path.wildcard(Path.join(src_path, "**/*.ts"))
      |> Enum.flat_map(&extract_typescript_imports/1)
    else
      []
    end
  end

  defp analyze_rust_dependencies(service_path) do
    # Scan Rust files for use statements
    src_path = Path.join(service_path, "src")

    if File.exists?(src_path) do
      Path.wildcard(Path.join(src_path, "**/*.rs"))
      |> Enum.flat_map(&extract_rust_imports/1)
    else
      []
    end
  end

  defp analyze_python_dependencies(service_path) do
    # Scan Python files for imports
    Path.wildcard(Path.join(service_path, "**/*.py"))
    |> Enum.flat_map(&extract_python_imports/1)
  end

  defp analyze_go_dependencies(service_path) do
    # Scan Go files for imports
    Path.wildcard(Path.join(service_path, "**/*.go"))
    |> Enum.flat_map(&extract_go_imports/1)
  end

  defp extract_typescript_imports(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        Regex.scan(~r/import.*from\s+['"]([^'"]+)['"]/, content)
        |> Enum.map(fn [_, import_path] ->
          %{
            target: normalize_import_path(import_path),
            type: :import,
            file_path: file_path,
            line_number: find_line_number(content, import_path)
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_rust_imports(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        Regex.scan(~r/use\s+([^;]+);/, content)
        |> Enum.map(fn [_, use_path] ->
          %{
            target: normalize_rust_path(use_path),
            type: :use,
            file_path: file_path,
            line_number: find_line_number(content, use_path)
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_python_imports(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        Regex.scan(~r/import\s+([^\s]+)/, content)
        |> Enum.map(fn [_, import_path] ->
          %{
            target: normalize_python_path(import_path),
            type: :import,
            file_path: file_path,
            line_number: find_line_number(content, import_path)
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_go_imports(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        Regex.scan(~r/import\s+['"]([^'"]+)['"]/, content)
        |> Enum.map(fn [_, import_path] ->
          %{
            target: normalize_go_path(import_path),
            type: :import,
            file_path: file_path,
            line_number: find_line_number(content, import_path)
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp normalize_import_path(path) do
    # Convert relative imports to service names
    cond do
      String.starts_with?(path, "./") -> extract_service_name_from_path(path)
      String.starts_with?(path, "../") -> extract_service_name_from_path(path)
      true -> path
    end
  end

  defp normalize_rust_path(path) do
    # Convert Rust crate paths to service names
    String.split(path, "::")
    |> List.first()
  end

  defp normalize_python_path(path) do
    # Convert Python module paths to service names
    String.split(path, ".")
    |> List.first()
  end

  defp normalize_go_path(path) do
    # Convert Go import paths to service names
    String.split(path, "/")
    |> List.last()
  end

  defp extract_service_name_from_path(path) do
    # Extract service name from relative path
    path
    |> String.replace(~r/^\.\.?\//, "")
    |> String.split("/")
    |> List.first()
  end

  defp find_line_number(content, search_text) do
    lines = String.split(content, "\n")

    Enum.find_index(lines, fn line ->
      String.contains?(line, search_text)
    end)
    |> case do
      nil -> 0
      index -> index + 1
    end
  end

  defp build_dependency_graph(dependencies) do
    graph =
      Enum.reduce(dependencies, %{}, fn dep, acc ->
        source = dep.source_service
        target = dep.target_service

        acc
        |> Map.update(source, [target], &[target | &1])
        |> Map.update(target, [], & &1)
      end)

    {:ok, graph}
  end

  defp count_dependencies(dependencies) do
    length(dependencies)
  end

  defp find_cycles_from_service(service, graph, visited) do
    if service in visited do
      # Found a cycle
      cycle_start = Enum.find_index(visited, &(&1 == service))
      cycle = Enum.slice(visited, cycle_start..-1) ++ [service]
      [cycle]
    else
      dependencies = Map.get(graph, service, [])

      Enum.flat_map(dependencies, fn dep ->
        find_cycles_from_service(dep, graph, [service | visited])
      end)
    end
  end

  defp group_services_by_domain(dependency_graph) do
    services = Map.keys(dependency_graph)

    Enum.group_by(services, fn service ->
      extract_domain_from_service_name(service)
    end)
  end

  defp extract_domain_from_service_name(service_name) do
    # Extract domain from service name (e.g., "platform-auth-service" -> "platform")
    case String.split(service_name, "-") do
      [domain | _] -> domain
      _ -> "unknown"
    end
  end

  defp find_high_coupling_services(dependency_graph) do
    Enum.map(dependency_graph, fn {service, dependencies} ->
      coupling_score = length(dependencies)
      {service, coupling_score}
    end)
    |> Enum.filter(fn {_service, score} -> score > 5 end)
    |> Enum.sort_by(fn {_service, score} -> score end, :desc)
  end

  defp find_duplicate_services(dependency_graph) do
    # Find services with similar names or functionality
    services = Map.keys(dependency_graph)

    # Group by name patterns
    name_groups =
      Enum.group_by(services, fn service ->
        # Extract base name (remove suffixes like -service, -api, etc.)
        service
        |> String.replace(~r/(-service|-api|-client|-server)$/, "")
        |> String.downcase()
      end)

    # Find groups with multiple services
    Enum.filter(name_groups, fn {_base_name, services} ->
      length(services) > 1
    end)
  end

  defp generate_consolidation_plan(domain_groups, high_coupling, duplicates) do
    %{
      domain_consolidation:
        Enum.map(domain_groups, fn {domain, services} ->
          %{
            domain: domain,
            services: services,
            consolidation_strategy: determine_domain_strategy(services)
          }
        end),
      coupling_consolidation:
        Enum.map(high_coupling, fn {service, score} ->
          %{
            service: service,
            coupling_score: score,
            consolidation_strategy: :merge_with_dependencies
          }
        end),
      duplicate_consolidation:
        Enum.map(duplicates, fn {base_name, services} ->
          %{
            base_name: base_name,
            services: services,
            consolidation_strategy: :merge_duplicates
          }
        end)
    }
  end

  defp determine_domain_strategy(services) do
    case length(services) do
      count when count > 5 -> :split_into_subdomains
      count when count > 2 -> :merge_related_services
      _ -> :keep_separate
    end
  end

  defp count_incoming_dependencies(service_name, dependency_graph) do
    Enum.count(dependency_graph, fn {_source, targets} ->
      service_name in targets
    end)
  end

  defp count_outgoing_dependencies(service_name, dependency_graph) do
    Map.get(dependency_graph, service_name, [])
    |> length()
  end

  defp determine_coupling_level(coupling_score) do
    cond do
      coupling_score >= 10 -> :high
      coupling_score >= 5 -> :medium
      coupling_score >= 2 -> :low
      true -> :minimal
    end
  end
end
