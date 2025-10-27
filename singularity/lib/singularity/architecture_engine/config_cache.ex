defmodule Singularity.ArchitectureEngine.ConfigCache do
  @moduledoc """
  ETS Manager for ArchitectureEngine configuration

  Manages ETS tables for workspace detection, build tool detection, and other configs.
  In production, this data comes from central Singularity.Jobs.PgmqClient. For testing, we use local ETS files.
  """

  require Logger

  @ets_tables %{
    workspace_detection: :workspace_detection,
    build_tool_detection: :build_tool_detection,
    package_manager_detection: :package_manager_detection,
    naming_conventions: :naming_conventions
  }

  @config_dir "priv/ets_configs"

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_state) do
    # Create ETS tables
    Enum.each(@ets_tables, fn {_name, table_name} ->
      :ets.new(table_name, [:named_table, :public, :set])
    end)

    # Load configuration from files
    load_configurations()

    {:ok, %{}}
  end

  @doc """
  Get workspace detection template by ID
  """
  def get_workspace_template(template_id) do
    case :ets.lookup(:workspace_detection, template_id) do
      [{^template_id, template}] -> {:ok, template}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Get all workspace detection templates
  """
  def get_all_workspace_templates do
    :ets.tab2list(:workspace_detection)
    |> Enum.map(fn {_id, template} -> template end)
  end

  @doc """
  Get build tool detection template by tool name
  """
  def get_build_tool_template(tool_name) do
    case :ets.lookup(:build_tool_detection, tool_name) do
      [{^tool_name, template}] -> {:ok, template}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Get all build tool detection templates
  """
  def get_all_build_tool_templates do
    :ets.tab2list(:build_tool_detection)
    |> Enum.map(fn {_name, template} -> template end)
  end

  @doc """
  Update configuration from central pgmq (future implementation)
  """
  def update_from_central_pgmq(config_type, data) do
    table_name = Map.get(@ets_tables, config_type)

    if table_name do
      # Clear existing data
      :ets.delete_all_objects(table_name)

      # Insert new data
      Enum.each(data, fn {key, value} ->
        :ets.insert(table_name, {key, value})
      end)

      Logger.info("Updated #{config_type} from central pgmq")
      :ok
    else
      {:error, :unknown_config_type}
    end
  end

  # Private functions

  defp load_configurations do
    load_workspace_detection()
    load_build_tool_detection()
    load_package_manager_detection()
    load_naming_conventions()
  end

  defp load_workspace_detection do
    config_file = Path.join(@config_dir, "workspace_detection.ets")

    if File.exists?(config_file) do
      case Code.eval_file(config_file) do
        {configs, _} ->
          Enum.each(configs, fn {key, value} ->
            :ets.insert(:workspace_detection, {key, value})
          end)

          Logger.info("Loaded workspace detection configs from ETS file")

        error ->
          Logger.warning("Failed to load workspace detection configs: #{inspect(error)}")
      end
    else
      Logger.warning("Workspace detection ETS file not found: #{config_file}")
    end
  end

  defp load_build_tool_detection do
    config_file = Path.join(@config_dir, "build_tool_detection.ets")

    if File.exists?(config_file) do
      case Code.eval_file(config_file) do
        {configs, _} ->
          Enum.each(configs, fn {key, value} ->
            :ets.insert(:build_tool_detection, {key, value})
          end)

          Logger.info("Loaded build tool detection configs from ETS file")

        error ->
          Logger.warning("Failed to load build tool detection configs: #{inspect(error)}")
      end
    else
      Logger.warning("Build tool detection ETS file not found: #{config_file}")
    end
  end

  defp load_package_manager_detection do
    # For now, use same data as build tool detection
    # In production, this would be separate
    build_tools = :ets.tab2list(:build_tool_detection)

    Enum.each(build_tools, fn {key, value} ->
      :ets.insert(:package_manager_detection, {key, value})
    end)
  end

  defp load_naming_conventions do
    # Load naming conventions from ETS file
    config_file = Path.join(@config_dir, "naming_conventions.ets")

    if File.exists?(config_file) do
      case Code.eval_file(config_file) do
        {configs, _} ->
          Enum.each(configs, fn {key, value} ->
            :ets.insert(:naming_conventions, {key, value})
          end)

          Logger.info("Loaded naming conventions from ETS file")

        error ->
          Logger.warning("Failed to load naming conventions: #{inspect(error)}")
      end
    else
      # Create default naming conventions
      create_default_naming_conventions()
    end
  end

  defp create_default_naming_conventions do
    default_conventions = [
      {
        "elixir",
        %{
          "functions" => "snake_case",
          "modules" => "PascalCase",
          "variables" => "snake_case",
          "atoms" => "snake_case",
          "files" => "snake_case",
          "directories" => "snake_case"
        }
      },
      {
        "rust",
        %{
          "functions" => "snake_case",
          "structs" => "PascalCase",
          "enums" => "PascalCase",
          "traits" => "PascalCase",
          "variables" => "snake_case",
          "files" => "snake_case"
        }
      },
      {
        "typescript",
        %{
          "functions" => "camelCase",
          "classes" => "PascalCase",
          "interfaces" => "PascalCase",
          "types" => "PascalCase",
          "variables" => "camelCase",
          "files" => "camelCase"
        }
      },
      {
        "gleam",
        %{
          "functions" => "snake_case",
          "types" => "PascalCase",
          "variables" => "snake_case",
          "files" => "snake_case",
          "directories" => "snake_case"
        }
      }
    ]

    Enum.each(default_conventions, fn {key, value} ->
      :ets.insert(:naming_conventions, {key, value})
    end)
  end
end
