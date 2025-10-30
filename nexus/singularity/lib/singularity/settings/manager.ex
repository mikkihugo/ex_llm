defmodule Singularity.Settings.Manager do
  @moduledoc """
  Management interface for application settings.

  Provides functions to get, set, list, and manage application settings
  stored in the PostgreSQL settings table.
  """

  alias Singularity.Settings
  alias Singularity.Repo

  @doc """
  Enable a pipeline's PGFlow mode.

  Example: enable_pipeline("code_quality")
  """
  def enable_pipeline(pipeline_name) do
    key = "pipelines.#{pipeline_name}.enabled"

    Settings.set(
      key,
      true,
      "Enable PGFlow mode for #{pipeline_name} pipeline",
      "pipelines",
      "manager"
    )
  end

  @doc """
  Disable a pipeline's PGFlow mode.

  Example: disable_pipeline("code_quality")
  """
  def disable_pipeline(pipeline_name) do
    key = "pipelines.#{pipeline_name}.enabled"

    Settings.set(
      key,
      false,
      "Disable PGFlow mode for #{pipeline_name} pipeline",
      "pipelines",
      "manager"
    )
  end

  @doc """
  Check if a pipeline's PGFlow mode is enabled.

  Example: pipeline_enabled?("code_quality")
  """
  def pipeline_enabled?(pipeline_name) do
    key = "pipelines.#{pipeline_name}.enabled"
    Settings.get_boolean(key, false)
  end

  @doc """
  Set a workflow timeout.

  Example: set_workflow_timeout("code_quality", 600_000)
  """
  def set_workflow_timeout(workflow_name, timeout_ms) do
    key = "workflows.#{workflow_name}.timeout_ms"
    Settings.set(key, timeout_ms, "Timeout for #{workflow_name} workflow", "workflows", "manager")
  end

  @doc """
  Get a workflow timeout.

  Example: get_workflow_timeout("code_quality")
  """
  def get_workflow_timeout(workflow_name, default \\ 300_000) do
    key = "workflows.#{workflow_name}.timeout_ms"
    Settings.get(key, default)
  end

  @doc """
  List all settings, optionally filtered by category.
  """
  def list_settings(category \\ nil) do
    Settings.all(category)
  end

  @doc """
  Get a setting value by key.
  """
  def get_setting(key) do
    Settings.get(key)
  end

  @doc """
  Set a setting value.
  """
  def set_setting(key, value, description \\ nil, category \\ nil) do
    Settings.set(key, value, description, category, "manager")
  end

  @doc """
  Delete a setting.
  """
  def delete_setting(key) do
    Settings.delete(key)
  end

  @doc """
  Initialize default settings for all pipelines.

  This ensures all expected settings exist with sensible defaults.
  """
  def initialize_defaults do
    # Pipeline enablement settings
    pipelines = [
      "code_quality",
      "complexity_training",
      "architecture_learning",
      "embedding_training"
    ]

    Enum.each(pipelines, fn pipeline ->
      key = "pipelines.#{pipeline}.enabled"
      description = "Enable PGFlow mode for #{String.replace(pipeline, "_", " ")} pipeline"
      Settings.set(key, false, description, "pipelines", "initializer")
    end)

    # Workflow timeout settings
    workflows = [
      "code_quality",
      "complexity_training",
      "architecture_learning",
      "embedding_training"
    ]

    timeout_defaults = %{
      "code_quality" => 300_000,
      "complexity_training" => 600_000,
      "architecture_learning" => 900_000,
      "embedding_training" => 300_000
    }

    Enum.each(workflows, fn workflow ->
      key = "workflows.#{workflow}.timeout_ms"
      description = "Timeout in milliseconds for #{String.replace(workflow, "_", " ")} workflow"
      default_timeout = Map.get(timeout_defaults, workflow, 300_000)
      Settings.set(key, default_timeout, description, "workflows", "initializer")
    end)

    :ok
  end

  @doc """
  Export settings to a map for backup or migration.
  """
  def export_settings do
    Repo.all(Settings)
    |> Enum.map(fn setting ->
      {setting.key,
       %{
         value: Settings.denormalize_value(setting.value),
         description: setting.description,
         category: setting.category,
         updated_at: setting.updated_at,
         updated_by: setting.updated_by
       }}
    end)
    |> Map.new()
  end

  @doc """
  Import settings from an exported map.
  """
  def import_settings(settings_map) do
    Enum.each(settings_map, fn {key, attrs} ->
      Settings.set(
        key,
        attrs.value,
        attrs.description,
        attrs.category,
        attrs[:updated_by] || "importer"
      )
    end)
  end
end
