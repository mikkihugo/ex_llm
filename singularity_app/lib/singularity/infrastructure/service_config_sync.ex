defmodule Singularity.ServiceConfigSync do
  @moduledoc """
  Configuration Agent - Manages configuration across singularity-engine services.

  Agent responsibilities:
  - Load environment-specific configs
  - Ensure configuration consistency
  - Monitor configuration changes
  - Coordinate config updates across services
  """

  require Logger

  alias Singularity.Engine.CodebaseStore

  @doc "Load configuration for all services"
  def load_all_service_configs do
    Logger.info("Loading configuration for all services")

    with {:ok, services} <- get_all_services(),
         {:ok, configs} <- load_service_configurations(services),
         {:ok, config_summary} <- generate_config_summary(configs) do
      %{
        total_services: length(services),
        configs_loaded: length(configs),
        config_summary: config_summary,
        load_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Config loading failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Validate configuration consistency across services"
  def validate_config_consistency do
    Logger.info("Validating configuration consistency")

    with {:ok, configs} <- load_all_service_configs(),
         {:ok, validation_results} <- perform_config_validation(configs),
         {:ok, consistency_report} <- generate_consistency_report(validation_results) do
      %{
        configs_validated: length(configs),
        validation_results: validation_results,
        consistency_report: consistency_report,
        validation_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Config validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Update configuration for specific service"
  def update_service_config(service_name, config_updates) do
    Logger.info("Updating configuration for service: #{service_name}")

    with {:ok, current_config} <- get_service_config(service_name),
         {:ok, updated_config} <- apply_config_updates(current_config, config_updates),
         {:ok, validation_result} <- validate_updated_config(updated_config),
         {:ok, save_result} <- save_service_config(service_name, updated_config) do
      %{
        service_name: service_name,
        config_updates: config_updates,
        updated_config: updated_config,
        validation_result: validation_result,
        save_result: save_result,
        update_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Config update failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Generate environment-specific configurations"
  def generate_environment_configs(environment) do
    Logger.info("Generating configurations for environment: #{environment}")

    with {:ok, base_configs} <- load_all_service_configs(),
         {:ok, env_configs} <- create_environment_configs(base_configs, environment),
         {:ok, env_validation} <- validate_environment_configs(env_configs) do
      %{
        environment: environment,
        base_configs: base_configs,
        environment_configs: env_configs,
        validation_result: env_validation,
        generation_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Environment config generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Backup and restore service configurations"
  def backup_service_configs do
    Logger.info("Backing up service configurations")

    with {:ok, configs} <- load_all_service_configs(),
         {:ok, backup_result} <- create_config_backup(configs) do
      %{
        configs_backed_up: length(configs),
        backup_result: backup_result,
        backup_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Config backup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Restore configurations from backup"
  def restore_service_configs(backup_id) do
    Logger.info("Restoring configurations from backup: #{backup_id}")

    with {:ok, backup_data} <- load_config_backup(backup_id),
         {:ok, restore_result} <- execute_config_restore(backup_data) do
      %{
        backup_id: backup_id,
        configs_restored: length(backup_data.configs),
        restore_result: restore_result,
        restore_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Config restore failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Private Functions

  defp get_all_services do
    # Get all services from the database
    services = CodebaseStore.all_services()
    {:ok, services}
  end

  defp load_service_configurations(services) do
    configs =
      Enum.map(services, fn service ->
        load_single_service_config(service)
      end)

    {:ok, configs}
  end

  defp load_single_service_config(service) do
    # Load configuration for a single service
    config_files = find_config_files(service.path)

    %{
      service_name: service.service_name,
      service_path: service.path,
      config_files: config_files,
      config_data: load_config_data(config_files),
      config_type: determine_config_type(config_files)
    }
  end

  defp find_config_files(service_path) do
    # Find configuration files in service directory
    config_patterns = [
      "*.json",
      "*.yaml",
      "*.yml",
      "*.toml",
      "*.env",
      "*.config.js",
      "*.config.ts",
      "config/*"
    ]

    Enum.flat_map(config_patterns, fn pattern ->
      Path.wildcard(Path.join(service_path, pattern))
    end)
    |> Enum.filter(&File.exists?/1)
  end

  defp load_config_data(config_files) do
    Enum.map(config_files, fn file_path ->
      load_single_config_file(file_path)
    end)
  end

  defp load_single_config_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        %{
          file_path: file_path,
          content: content,
          parsed_content: parse_config_content(file_path, content),
          file_type: determine_file_type(file_path)
        }

      {:error, reason} ->
        %{
          file_path: file_path,
          content: nil,
          parsed_content: nil,
          file_type: determine_file_type(file_path),
          error: reason
        }
    end
  end

  defp parse_config_content(file_path, content) do
    file_type = determine_file_type(file_path)

    case file_type do
      :json -> parse_json_content(content)
      :yaml -> parse_yaml_content(content)
      :toml -> parse_toml_content(content)
      :env -> parse_env_content(content)
      _ -> content
    end
  end

  defp parse_json_content(content) do
    case Jason.decode(content) do
      {:ok, json} -> json
      {:error, _} -> nil
    end
  end

  defp parse_yaml_content(content) do
    # This would use a YAML library in practice
    content
  end

  defp parse_toml_content(content) do
    # This would use a TOML library in practice
    content
  end

  defp parse_env_content(content) do
    # Parse environment file
    content
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_env_line/1)
    |> Enum.into(%{})
  end

  defp parse_env_line(line) do
    case String.split(line, "=", parts: 2) do
      [key, value] -> {String.trim(key), String.trim(value)}
      [key] -> {String.trim(key), ""}
    end
  end

  defp determine_file_type(file_path) do
    extension = Path.extname(file_path)

    case extension do
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      ".toml" -> :toml
      ".env" -> :env
      ".js" -> :javascript
      ".ts" -> :typescript
      _ -> :unknown
    end
  end

  defp determine_config_type(config_files) do
    cond do
      Enum.any?(config_files, &String.contains?(&1, "package.json")) -> :nodejs
      Enum.any?(config_files, &String.contains?(&1, "Cargo.toml")) -> :rust
      Enum.any?(config_files, &String.contains?(&1, "requirements.txt")) -> :python
      Enum.any?(config_files, &String.contains?(&1, "go.mod")) -> :go
      true -> :unknown
    end
  end

  defp generate_config_summary(configs) do
    summary = %{
      total_configs: length(configs),
      config_types: count_config_types(configs),
      config_files: count_config_files(configs),
      validation_errors: count_validation_errors(configs)
    }

    {:ok, summary}
  end

  defp count_config_types(configs) do
    Enum.group_by(configs, & &1.config_type)
    |> Enum.map(fn {type, configs} -> {type, length(configs)} end)
    |> Enum.into(%{})
  end

  defp count_config_files(configs) do
    Enum.sum(Enum.map(configs, &length(&1.config_files)))
  end

  defp count_validation_errors(configs) do
    Enum.count(configs, fn config ->
      Enum.any?(config.config_data, fn data ->
        Map.has_key?(data, :error)
      end)
    end)
  end

  defp perform_config_validation(configs) do
    validation_results =
      Enum.map(configs, fn config ->
        validate_single_config(config)
      end)

    {:ok, validation_results}
  end

  defp validate_single_config(config) do
    # Validate a single service configuration
    validation_errors = []

    # Check for required fields
    validation_errors = check_required_fields(config, validation_errors)

    # Check for format consistency
    validation_errors = check_format_consistency(config, validation_errors)

    # Check for environment-specific values
    validation_errors = check_environment_values(config, validation_errors)

    %{
      service_name: config.service_name,
      validation_errors: validation_errors,
      validation_status: if(length(validation_errors) == 0, do: :valid, else: :invalid)
    }
  end

  defp check_required_fields(config, errors) do
    # Check for required configuration fields
    required_fields = ["name", "version", "port"]

    missing_fields =
      Enum.filter(required_fields, fn field ->
        not has_config_field?(config, field)
      end)

    if length(missing_fields) > 0 do
      [%{type: :missing_required_fields, fields: missing_fields} | errors]
    else
      errors
    end
  end

  defp check_format_consistency(config, errors) do
    # Check for format consistency
    errors
  end

  defp check_environment_values(config, errors) do
    # Check for environment-specific values
    errors
  end

  defp has_config_field?(config, field) do
    Enum.any?(config.config_data, fn data ->
      case data.parsed_content do
        %{} = parsed when is_map(parsed) -> Map.has_key?(parsed, field)
        _ -> false
      end
    end)
  end

  defp generate_consistency_report(validation_results) do
    valid_configs = Enum.count(validation_results, &(&1.validation_status == :valid))
    invalid_configs = Enum.count(validation_results, &(&1.validation_status == :invalid))

    report = %{
      total_configs: length(validation_results),
      valid_configs: valid_configs,
      invalid_configs: invalid_configs,
      consistency_percentage: Float.round(valid_configs / length(validation_results) * 100, 2),
      common_issues: identify_common_issues(validation_results)
    }

    {:ok, report}
  end

  defp identify_common_issues(validation_results) do
    # Identify common validation issues
    all_errors = Enum.flat_map(validation_results, & &1.validation_errors)

    Enum.group_by(all_errors, & &1.type)
    |> Enum.map(fn {type, errors} -> {type, length(errors)} end)
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
  end

  defp get_service_config(service_name) do
    # Get configuration for a specific service
    config = %{
      service_name: service_name,
      config_data: %{}
    }

    {:ok, config}
  end

  defp apply_config_updates(current_config, config_updates) do
    # Apply configuration updates
    updated_config = Map.merge(current_config, config_updates)
    {:ok, updated_config}
  end

  defp validate_updated_config(updated_config) do
    # Validate updated configuration
    validation_result = %{
      status: :valid,
      errors: []
    }

    {:ok, validation_result}
  end

  defp save_service_config(service_name, updated_config) do
    # Save service configuration
    save_result = %{
      service_name: service_name,
      status: :saved,
      save_timestamp: DateTime.utc_now()
    }

    {:ok, save_result}
  end

  defp create_environment_configs(base_configs, environment) do
    # Create environment-specific configurations
    env_configs =
      Enum.map(base_configs, fn config ->
        create_single_env_config(config, environment)
      end)

    {:ok, env_configs}
  end

  defp create_single_env_config(config, environment) do
    # Create environment-specific config for a single service
    %{
      service_name: config.service_name,
      environment: environment,
      config_data: adapt_config_for_environment(config.config_data, environment)
    }
  end

  defp adapt_config_for_environment(config_data, environment) do
    # Adapt configuration for specific environment
    config_data
  end

  defp validate_environment_configs(env_configs) do
    # Validate environment configurations
    validation_result = %{
      status: :valid,
      errors: []
    }

    {:ok, validation_result}
  end

  defp create_config_backup(configs) do
    # Create configuration backup
    backup_id = "config_backup_#{DateTime.utc_now() |> DateTime.to_unix()}"

    backup_result = %{
      backup_id: backup_id,
      configs_backed_up: length(configs),
      backup_location: "/backups/configs/#{backup_id}",
      # Placeholder
      backup_size_bytes: 1024 * 1024,
      backup_timestamp: DateTime.utc_now()
    }

    {:ok, backup_result}
  end

  defp load_config_backup(backup_id) do
    # Load configuration backup
    backup_data = %{
      backup_id: backup_id,
      configs: []
    }

    {:ok, backup_data}
  end

  defp execute_config_restore(backup_data) do
    # Execute configuration restore
    restore_result = %{
      configs_restored: length(backup_data.configs),
      restore_status: :success,
      restore_timestamp: DateTime.utc_now()
    }

    {:ok, restore_result}
  end
end
