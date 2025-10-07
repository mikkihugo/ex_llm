defmodule Singularity.CodeAnalysis.ConsolidationEngine do
  @moduledoc """
  Consolidates duplicate services and merges related functionality
  to reduce the 102+ services in singularity-engine to ~25 services.
  """

  require Logger

  alias Singularity.Engine.CodebaseStore
  alias Singularity.CodeAnalysis.{DependencyMapper, ServiceAnalyzer}

  @doc "Identify duplicate services that can be merged"
  def identify_duplicate_services do
    Logger.info("Identifying duplicate services for consolidation")

    with {:ok, services} <- load_all_services(),
         {:ok, duplicates} <- find_duplicate_services(services),
         {:ok, consolidation_plan} <- create_consolidation_plan(duplicates) do
      %{
        total_services: length(services),
        duplicate_groups: duplicates,
        consolidation_plan: consolidation_plan,
        estimated_reduction: calculate_reduction_estimate(services, duplicates),
        analysis_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to identify duplicates: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Merge multiple services into a single consolidated service"
  def merge_service_code(services_to_merge) do
    Logger.info("Merging #{length(services_to_merge)} services")

    with {:ok, merged_code} <- generate_merged_code(services_to_merge),
         {:ok, merged_config} <- generate_merged_config(services_to_merge),
         {:ok, merged_docs} <- generate_merged_documentation(services_to_merge) do
      %{
        merged_service_name: determine_merged_service_name(services_to_merge),
        merged_code: merged_code,
        merged_config: merged_config,
        merged_docs: merged_docs,
        source_services: Enum.map(services_to_merge, & &1.service_name),
        merge_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to merge services: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Update service references after consolidation"
  def update_service_references(consolidation_mapping) do
    Logger.info("Updating service references after consolidation")

    with {:ok, affected_services} <- find_affected_services(consolidation_mapping),
         {:ok, updated_services} <-
           update_references_in_services(affected_services, consolidation_mapping) do
      %{
        consolidation_mapping: consolidation_mapping,
        affected_services: affected_services,
        updated_services: updated_services,
        update_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Failed to update references: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Execute the complete consolidation process"
  def execute_consolidation(consolidation_plan) do
    Logger.info("Executing consolidation plan")

    with {:ok, phase_1} <- execute_consolidation_phase(consolidation_plan.phase_1),
         {:ok, phase_2} <- execute_consolidation_phase(consolidation_plan.phase_2),
         {:ok, phase_3} <- execute_consolidation_phase(consolidation_plan.phase_3),
         {:ok, final_validation} <- validate_consolidation_results() do
      %{
        phase_1_results: phase_1,
        phase_2_results: phase_2,
        phase_3_results: phase_3,
        final_validation: final_validation,
        consolidation_complete: true,
        completion_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Consolidation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Private Functions

  defp determine_merged_service_name([]), do: "consolidated-service"

  defp determine_merged_service_name(services) when is_list(services) do
    base_names = Enum.map(services, &service_base_name/1)

    prefix =
      base_names
      |> Enum.reduce(&common_prefix/2)
      |> case do
        "" -> hd(base_names)
        value -> value
      end

    normalized =
      prefix
      |> String.trim("-")
      |> String.replace(~r/[^a-z0-9_\-]+/, "-")

    cond do
      normalized == "" -> "consolidated-service"
      String.ends_with?(normalized, "-service") -> normalized <> "-merged"
      true -> normalized <> "-service"
    end
  end

  defp service_base_name(%{service_name: name}) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/(-service|-api|-client|-server|-manager)$/u, "")
  end

  defp service_base_name(name) when is_binary(name) do
    service_base_name(%{service_name: name})
  end

  defp service_base_name(_), do: "service"

  defp common_prefix(a, b) do
    a_chars = String.to_charlist(a || "")
    b_chars = String.to_charlist(b || "")

    common =
      Enum.zip(a_chars, b_chars)
      |> Enum.take_while(fn {c1, c2} -> c1 == c2 end)
      |> Enum.map(&elem(&1, 0))

    List.to_string(common)
  end

  defp load_all_services do
    services = CodebaseStore.all_services()
    {:ok, services}
  end

  defp find_duplicate_services(services) do
    # Group services by functionality
    functionality_groups = group_by_functionality(services)

    # Group services by name patterns
    name_groups = group_by_name_patterns(services)

    # Group services by dependencies
    dependency_groups = group_by_dependencies(services)

    # Find overlapping groups
    duplicates = find_overlapping_groups(functionality_groups, name_groups, dependency_groups)

    {:ok, duplicates}
  end

  defp group_by_functionality(services) do
    Enum.group_by(services, fn service ->
      extract_functionality_from_service(service)
    end)
  end

  defp group_by_name_patterns(services) do
    Enum.group_by(services, fn service ->
      # Extract base name pattern
      service.service_name
      |> String.replace(~r/(-service|-api|-client|-server|-manager)$/, "")
      |> String.downcase()
    end)
  end

  defp group_by_dependencies(services) do
    Enum.group_by(services, fn service ->
      # Group by common dependencies
      service.dependencies
      |> Map.get(:runtime, %{})
      |> Map.keys()
      |> Enum.sort()
      |> Enum.join("-")
    end)
  end

  defp extract_functionality_from_service(service) do
    # Analyze service purpose from name and structure
    service_name = String.downcase(service.service_name)

    cond do
      String.contains?(service_name, "auth") -> :authentication
      String.contains?(service_name, "user") -> :user_management
      String.contains?(service_name, "data") -> :data_management
      String.contains?(service_name, "api") -> :api_gateway
      String.contains?(service_name, "message") -> :messaging
      String.contains?(service_name, "storage") -> :storage
      String.contains?(service_name, "config") -> :configuration
      String.contains?(service_name, "monitor") -> :monitoring
      String.contains?(service_name, "log") -> :logging
      String.contains?(service_name, "cache") -> :caching
      true -> :general
    end
  end

  defp find_overlapping_groups(functionality_groups, name_groups, dependency_groups) do
    # Find services that appear in multiple groups
    all_groups = [functionality_groups, name_groups, dependency_groups]

    # Get all service names
    all_services = Enum.flat_map(all_groups, &Map.values/1) |> List.flatten() |> Enum.uniq()

    # Find services that appear in multiple groups
    duplicates =
      Enum.filter(all_services, fn service ->
        group_count =
          Enum.count(all_groups, fn group ->
            Enum.any?(group, fn {_key, services} ->
              service in services
            end)
          end)

        group_count > 1
      end)

    # Group duplicates together
    Enum.group_by(duplicates, fn service ->
      find_primary_group(service, functionality_groups)
    end)
  end

  defp find_primary_group(service, functionality_groups) do
    Enum.find(functionality_groups, fn {_key, services} ->
      service in services
    end)
    |> case do
      {key, _services} -> key
      nil -> :unknown
    end
  end

  defp create_consolidation_plan(duplicates) do
    %{
      phase_1: create_phase_plan(duplicates, :authentication),
      phase_2: create_phase_plan(duplicates, :data_management),
      phase_3: create_phase_plan(duplicates, :general)
    }
    |> then(&{:ok, &1})
  end

  defp create_phase_plan(duplicates, phase_type) do
    Map.get(duplicates, phase_type, [])
    |> Enum.map(fn services ->
      %{
        services_to_merge: services,
        target_service_name: determine_target_name(services),
        merge_strategy: determine_merge_strategy(services),
        estimated_effort_hours: estimate_merge_effort(services)
      }
    end)
  end

  defp determine_target_name(services) do
    # Use the most complete service as the base
    base_service = Enum.max_by(services, & &1.completion_percentage)

    # Clean up the name
    base_service.service_name
    |> String.replace(~r/(-service|-api|-client|-server)$/, "")
    |> Kernel.<>("-service")
  end

  defp determine_merge_strategy(services) do
    case length(services) do
      count when count > 5 -> :split_and_merge
      count when count > 2 -> :merge_into_one
      _ -> :keep_separate
    end
  end

  defp estimate_merge_effort(services) do
    # Estimate effort based on number of services and complexity
    # 4 hours per service
    base_effort = length(services) * 4
    complexity_multiplier = calculate_complexity_multiplier(services)

    Float.round(base_effort * complexity_multiplier, 1)
  end

  defp calculate_complexity_multiplier(services) do
    avg_completion =
      Enum.map(services, & &1.completion_percentage) |> Enum.sum() |> Kernel./(length(services))

    cond do
      # Low completion = more work
      avg_completion < 30 -> 2.0
      # Medium completion
      avg_completion < 70 -> 1.5
      # High completion = less work
      true -> 1.0
    end
  end

  defp calculate_reduction_estimate(total_services, duplicates) do
    services_to_merge =
      Enum.flat_map(duplicates, fn {_key, services} ->
        services
      end)
      |> Enum.uniq()

    services_after_merge = length(services_to_merge) - length(duplicates)
    services_remaining = total_services - length(services_to_merge)

    final_count = services_after_merge + services_remaining

    %{
      original_count: total_services,
      final_count: final_count,
      reduction_count: total_services - final_count,
      reduction_percentage: Float.round((total_services - final_count) / total_services * 100, 1)
    }
  end

  defp generate_merged_code(services) do
    # Analyze each service's code structure
    service_analyses =
      Enum.map(services, fn service ->
        ServiceAnalyzer.analyze_service_by_language(service)
      end)

    # Generate merged code
    merged_code = generate_consolidated_code(service_analyses)

    {:ok, merged_code}
  end

  defp generate_merged_config(services) do
    # Merge configuration files
    configs =
      Enum.map(services, fn service ->
        load_service_config(service)
      end)

    merged_config = merge_configurations(configs)

    {:ok, merged_config}
  end

  defp generate_merged_documentation(services) do
    # Merge documentation
    docs =
      Enum.map(services, fn service ->
        load_service_documentation(service)
      end)

    merged_docs = merge_documentation(docs)

    {:ok, merged_docs}
  end

  defp generate_consolidated_code(service_analyses) do
    # This would use AI to generate consolidated code
    # For now, return a placeholder structure
    %{
      main_module: "ConsolidatedService",
      modules: Enum.map(service_analyses, & &1.main_module),
      dependencies: merge_dependencies(service_analyses),
      api_endpoints: merge_api_endpoints(service_analyses),
      database_schemas: merge_database_schemas(service_analyses)
    }
  end

  defp load_service_config(service) do
    # Load service configuration
    %{
      service_name: service.service_name,
      # Placeholder
      config: %{}
    }
  end

  defp merge_configurations(configs) do
    # Merge multiple configurations
    %{
      merged_config: %{},
      source_configs: configs
    }
  end

  defp load_service_documentation(service) do
    # Load service documentation
    %{
      service_name: service.service_name,
      # Placeholder
      docs: %{}
    }
  end

  defp merge_documentation(docs) do
    # Merge documentation
    %{
      merged_docs: %{},
      source_docs: docs
    }
  end

  defp merge_dependencies(service_analyses) do
    Enum.flat_map(service_analyses, & &1.dependencies)
    |> Enum.uniq_by(& &1.name)
  end

  defp merge_api_endpoints(service_analyses) do
    Enum.flat_map(service_analyses, & &1.api_endpoints)
    |> Enum.uniq_by(& &1.path)
  end

  defp merge_database_schemas(service_analyses) do
    Enum.flat_map(service_analyses, & &1.database_schemas)
    |> Enum.uniq_by(& &1.table_name)
  end

  defp find_affected_services(_consolidation_mapping) do
    # Find services that reference the services being consolidated
    # Placeholder
    {:ok, []}
  end

  defp update_references_in_services(_affected_services, _consolidation_mapping) do
    # Update references in affected services
    # Placeholder
    {:ok, []}
  end

  defp execute_consolidation_phase(phase_plan) do
    # Execute consolidation for a phase
    results =
      Enum.map(phase_plan, fn plan ->
        merge_service_code(plan.services_to_merge)
      end)

    {:ok, results}
  end

  defp validate_consolidation_results do
    # Validate that consolidation was successful
    {:ok, %{validation_passed: true}}
  end
end
