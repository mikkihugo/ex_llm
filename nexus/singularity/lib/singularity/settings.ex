defmodule Singularity.Settings do
  @moduledoc """
  PostgreSQL-backed configuration settings system.

  Provides a key-value store for application settings with self-documenting names.
  Falls back to environment variables when database settings are unavailable.

  Settings are stored in the `settings` table with the following schema:
  - key: string (primary key) - self-documenting setting name
  - value: jsonb - setting value (can be string, number, boolean, or complex object)
  - description: text - human-readable description of the setting
  - category: string - grouping category (e.g., "pipelines", "workflows", "features")
  - updated_at: timestamp - last modification time
  - updated_by: string - who last updated the setting
  """

  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias Singularity.Repo

  schema "settings" do
    field :key, :string, primary_key: true
    # jsonb field for flexible value types
    field :value, :map
    field :description, :string
    field :category, :string
    field :updated_by, :string

    timestamps(updated_at: :updated_at, inserted_at: false)
  end

  @doc """
  Get a setting value by key, with optional default fallback.

  First checks database, then falls back to environment variable, then to provided default.
  """
  def get(key, default \\ nil) do
    case get_from_db(key) do
      {:ok, value} -> value
      {:error, _} -> get_from_env(key, default)
    end
  end

  @doc """
  Get a boolean setting value.

  Returns true if the setting value is "true", "1", or true.
  """
  def get_boolean(key, default \\ false) do
    value = get(key, default)

    case value do
      "true" -> true
      "1" -> true
      true -> true
      "false" -> false
      "0" -> false
      false -> false
      _ -> default
    end
  end

  @doc """
  Set a setting value in the database.
  """
  def set(key, value, description \\ nil, category \\ nil, updated_by \\ "system") do
    # Convert value to map format for jsonb storage
    value_map = normalize_value(value)

    attrs = %{
      key: key,
      value: value_map,
      description: description || get_description(key),
      category: category || get_category(key),
      updated_by: updated_by
    }

    case Repo.get(__MODULE__, key) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Get all settings, optionally filtered by category.
  """
  def all(category \\ nil) do
    query = from s in __MODULE__, order_by: [s.category, s.key]

    query =
      if category do
        from s in query, where: s.category == ^category
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Delete a setting.
  """
  def delete(key) do
    case Repo.get(__MODULE__, key) do
      nil -> {:error, :not_found}
      setting -> Repo.delete(setting)
    end
  end

  # Private functions

  defp get_from_db(key) do
    case Repo.get(__MODULE__, key) do
      nil -> {:error, :not_found}
      setting -> {:ok, denormalize_value(setting.value)}
    end
  end

  defp get_from_env(key, default) do
    env_key = key_to_env_var(key)
    System.get_env(env_key, default)
  end

  defp key_to_env_var(key) do
    key
    |> String.upcase()
    |> String.replace(".", "_")
    |> String.replace("-", "_")
  end

  defp normalize_value(value) do
    case value do
      nil -> %{"type" => "null", "value" => nil}
      true -> %{"type" => "boolean", "value" => true}
      false -> %{"type" => "boolean", "value" => false}
      value when is_binary(value) -> %{"type" => "string", "value" => value}
      value when is_number(value) -> %{"type" => "number", "value" => value}
      value when is_map(value) -> %{"type" => "object", "value" => value}
      value when is_list(value) -> %{"type" => "array", "value" => value}
      _ -> %{"type" => "string", "value" => to_string(value)}
    end
  end

  defp denormalize_value(%{"type" => "null"}) do
    nil
  end

  defp denormalize_value(%{"type" => "boolean", "value" => value}) do
    value
  end

  defp denormalize_value(%{"type" => "string", "value" => value}) do
    value
  end

  defp denormalize_value(%{"type" => "number", "value" => value}) do
    value
  end

  defp denormalize_value(%{"type" => "object", "value" => value}) do
    value
  end

  defp denormalize_value(%{"type" => "array", "value" => value}) do
    value
  end

  @doc """
  Creates a changeset for a setting.

  ## Examples

      iex> changeset(%Singularity.Settings{}, %{key: "test.key", value: %{"type" => "string", "value" => "test"}})
      %Ecto.Changeset{}

  """
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value, :description, :category, :updated_by])
    |> validate_required([:key, :value])
    |> unique_constraint(:key)
  end

  # Self-documenting setting descriptions and categories

  defp get_description(key) do
    case key do
      "pipelines.code_quality.enabled" ->
        "Enable PGFlow mode for code quality training pipeline"

      "pipelines.complexity_training.enabled" ->
        "Enable PGFlow mode for complexity analysis training pipeline"

      "pipelines.architecture_learning.enabled" ->
        "Enable PGFlow mode for architecture learning pipeline"

      "pipelines.embedding_training.enabled" ->
        "Enable PGFlow mode for embedding training pipeline"

      "workflows.code_quality.timeout_ms" ->
        "Timeout in milliseconds for code quality training workflow"

      "workflows.complexity_training.timeout_ms" ->
        "Timeout in milliseconds for complexity training workflow"

      "workflows.architecture_learning.timeout_ms" ->
        "Timeout in milliseconds for architecture learning workflow"

      "workflows.embedding_training.timeout_ms" ->
        "Timeout in milliseconds for embedding training workflow"

      _ ->
        "Configuration setting for #{key}"
    end
  end

  defp get_category(key) do
    cond do
      String.starts_with?(key, "pipelines.") -> "pipelines"
      String.starts_with?(key, "workflows.") -> "workflows"
      String.starts_with?(key, "features.") -> "features"
      String.starts_with?(key, "database.") -> "database"
      String.starts_with?(key, "api.") -> "api"
      true -> "general"
    end
  end
end
