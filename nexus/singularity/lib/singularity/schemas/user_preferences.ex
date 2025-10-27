defmodule Singularity.Schemas.UserPreferences do
  @moduledoc """
  User Preferences schema for managing user-specific settings and configurations.

  Stores user preferences as JSONB for flexible schema evolution and
  supports both structured queries and semantic search via embeddings.

  ## Features

  - **Flexible Storage**: JSONB fields for extensible preference structure
  - **User Isolation**: Each user has independent preference sets
  - **Versioning**: Track preference changes over time
  - **Semantic Search**: Vector embeddings for preference discovery
  - **Validation**: Type-safe preference validation with custom rules

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.UserPreferences",
    "purpose": "User-specific settings, preferences, and configurations",
    "role": "schema",
    "layer": "domain_services",
    "table": "user_preferences",
    "features": ["user_settings", "preference_management", "flexible_storage"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - user_id: User owning these preferences
    - preferences: JSONB with flexible preference structure
    - embedding: Vector for semantic preference search
    - version: Preference schema version
    - updated_at: Last modification timestamp
  ```

  ### Anti-Patterns
  - ❌ DO NOT use for multi-user settings - this is per-user
  - ❌ DO NOT store sensitive data here - use vault
  - ✅ DO use for extensible user configuration
  - ✅ DO rely on JSONB for schema flexibility

  ### Search Keywords
  user_preferences, settings, configuration, user_settings, customization,
  flexible_storage, jsonb, user_experience
  ```

  ## Usage

      # Create user preferences
      {:ok, prefs} = UserPreferences.create(%{
        user_id: "user_123",
        preferences: %{
          theme: "dark",
          language: "en",
          notifications: %{email: true, push: false}
        }
      })

      # Update preferences
      {:ok, updated} = UserPreferences.update(prefs, %{
        preferences: %{theme: "light", language: "es"}
      })

      # Search by preference content
      UserPreferences.by_preference_value("theme", "dark")
  """

  use Ecto.Schema
  import Ecto.{Changeset, Query}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_preferences" do
    # User identification
    field :user_id, :string
    field :preference_type, :string, default: "general"

    # Flexible preference storage
    field :preferences, :map, default: %{}
    field :metadata, :map, default: %{}

    # Semantic search support
    field :embedding, Pgvector.Ecto.Vector

    # Versioning and tracking
    field :version, :string, default: "1.0.0"
    field :is_active, :boolean, default: true
    field :created_by, :string
    field :change_reason, :string

    # Previous version reference
    belongs_to :previous_version, __MODULE__, type: :binary_id

    # Virtual fields for common preferences
    field :theme, :string, virtual: true
    field :language, :string, virtual: true
    field :notifications, :map, virtual: true

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: binary(),
          user_id: String.t(),
          preference_type: String.t(),
          preferences: map(),
          metadata: map(),
          embedding: Pgvector.Ecto.Vector.t() | nil,
          version: String.t(),
          is_active: boolean(),
          created_by: String.t() | nil,
          change_reason: String.t() | nil,
          previous_version_id: binary() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Changeset for creating/updating user preferences.
  """
  def changeset(preferences, attrs) do
    preferences
    |> cast(attrs, [
      :user_id,
      :preference_type,
      :preferences,
      :metadata,
      :embedding,
      :version,
      :is_active,
      :created_by,
      :change_reason,
      :previous_version_id
    ])
    |> validate_required([:user_id, :preference_type, :preferences])
    |> validate_inclusion(:preference_type, [
      "general",
      "ui",
      "notifications",
      "privacy",
      "advanced"
    ])
    |> validate_preferences()
    |> validate_metadata()
    |> validate_embedding()
    |> unique_constraint([:user_id, :preference_type, :version])
  end

  @doc """
  Changeset for updating preferences (preserves version history).
  """
  def update_changeset(preferences, attrs) do
    preferences
    |> cast(attrs, [:preferences, :metadata, :change_reason])
    |> validate_preferences()
    |> validate_metadata()
  end

  @doc """
  Changeset for deactivating preferences.
  """
  def deactivate_changeset(preferences, reason \\ "user_request") do
    preferences
    |> change(%{is_active: false, change_reason: reason})
  end

  ## Query Helpers

  @doc """
  Get active preferences for a user.
  """
  def for_user(query \\ __MODULE__, user_id) do
    from p in query,
      where: p.user_id == ^user_id and p.is_active == true,
      order_by: [desc: p.updated_at]
  end

  @doc """
  Get preferences by type for a user.
  """
  def for_user_by_type(query \\ __MODULE__, user_id, type) do
    from p in query,
      where: p.user_id == ^user_id and p.preference_type == ^type and p.is_active == true,
      order_by: [desc: p.updated_at],
      limit: 1
  end

  @doc """
  Find preferences by specific preference value.
  """
  def by_preference_value(query \\ __MODULE__, key, value) do
    from p in query,
      where: fragment("?->>? = ?", p.preferences, ^key, ^value),
      where: p.is_active == true
  end

  @doc """
  Find preferences by preference key existence.
  """
  def with_preference_key(query \\ __MODULE__, key) do
    from p in query,
      where: fragment("? -> ? IS NOT NULL", p.preferences, ^key),
      where: p.is_active == true
  end

  @doc """
  Semantic search by embedding similarity.
  """
  def semantic_search(query \\ __MODULE__, embedding, limit \\ 10) do
    from p in query,
      where: not is_nil(p.embedding),
      where: p.is_active == true,
      order_by: fragment("embedding <-> ?", ^embedding),
      limit: ^limit
  end

  @doc """
  Get preference history for a user.
  """
  def history_for_user(query \\ __MODULE__, user_id, type \\ nil) do
    base_query = from p in query, where: p.user_id == ^user_id

    query_with_type =
      if type do
        from p in base_query, where: p.preference_type == ^type
      else
        base_query
      end

    from p in query_with_type,
      order_by: [desc: p.updated_at],
      preload: [:previous_version]
  end

  @doc """
  Find users with similar preferences.
  """
  def similar_users(query \\ __MODULE__, user_id, limit \\ 5) do
    # Find similar users by preference similarity
    from p in query,
      where: p.user_id != ^user_id,
      where: p.is_active == true,
      where: not is_nil(p.embedding),
      order_by:
        fragment(
          "embedding <-> (SELECT embedding FROM user_preferences WHERE user_id = ? AND is_active = true LIMIT 1)",
          ^user_id
        ),
      limit: ^limit
  end

  @doc """
  Get preference statistics.
  """
  def statistics(query \\ __MODULE__) do
    from p in query,
      where: p.is_active == true,
      select: %{
        total_users: count(p.user_id, :distinct),
        total_preferences: count(p.id),
        by_type: fragment("jsonb_object_agg(?, count(*))", p.preference_type),
        last_updated: max(p.updated_at)
      }
  end

  @doc """
  Get preferences created within a date range.
  """
  def created_between(query \\ __MODULE__, start_date, end_date) do
    from p in query,
      where: p.inserted_at >= ^start_date,
      where: p.inserted_at <= ^end_date,
      where: p.is_active == true,
      order_by: [desc: p.inserted_at]
  end

  @doc """
  Get preferences with specific metadata key.
  """
  def with_metadata_key(query \\ __MODULE__, key) do
    from p in query,
      where: fragment("? -> ? IS NOT NULL", p.metadata, ^key),
      where: p.is_active == true
  end

  @doc """
  Get preferences by metadata value.
  """
  def by_metadata_value(query \\ __MODULE__, key, value) do
    from p in query,
      where: fragment("?->>? = ?", p.metadata, ^key, ^value),
      where: p.is_active == true
  end

  @doc """
  Get inactive preferences for cleanup.
  """
  def inactive_preferences(query \\ __MODULE__, older_than_days \\ 30) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-older_than_days * 24 * 60 * 60, :second)

    from p in query,
      where: p.is_active == false,
      where: p.updated_at < ^cutoff_date,
      order_by: [asc: p.updated_at]
  end

  @doc """
  Bulk deactivate preferences for a user.
  """
  def bulk_deactivate_for_user(user_id, reason \\ "bulk_cleanup") do
    from p in __MODULE__,
      where: p.user_id == ^user_id,
      where: p.is_active == true,
      update: [set: [is_active: false, change_reason: ^reason, updated_at: fragment("NOW()")]]
  end

  ## Utility Functions

  @doc """
  Extract virtual fields from preferences map.
  """
  def extract_virtual_fields(%__MODULE__{preferences: preferences} = struct) do
    %{
      struct
      | theme: preferences["theme"],
        language: preferences["language"],
        notifications: preferences["notifications"]
    }
  end

  @doc """
  Create a new version of preferences with change tracking.
  """
  def create_new_version(%__MODULE__{} = current, new_preferences, change_reason, created_by) do
    %{
      user_id: current.user_id,
      preference_type: current.preference_type,
      preferences: new_preferences,
      metadata: current.metadata,
      version: increment_version(current.version),
      is_active: true,
      created_by: created_by,
      change_reason: change_reason,
      previous_version_id: current.id
    }
  end

  @doc """
  Get preference value with default fallback.
  """
  def get_preference_value(%__MODULE__{preferences: preferences}, key, default \\ nil) do
    Map.get(preferences, key, default)
  end

  @doc """
  Set preference value and return updated preferences map.
  """
  def set_preference_value(%__MODULE__{preferences: preferences}, key, value) do
    Map.put(preferences, key, value)
  end

  @doc """
  Merge new preferences with existing ones.
  """
  def merge_preferences(%__MODULE__{preferences: existing}, new_prefs) when is_map(new_prefs) do
    Map.merge(existing, new_prefs)
  end

  @doc """
  Check if preference key exists and has a truthy value.
  """
  def preference_enabled?(%__MODULE__{preferences: preferences}, key) do
    case Map.get(preferences, key) do
      nil -> false
      false -> false
      "" -> false
      [] -> false
      _ -> true
    end
  end

  ## Private Helpers

  defp increment_version(version) do
    # Simple semantic versioning increment (patch version)
    case String.split(version, ".") do
      [major, minor, patch] ->
        {patch_num, _} = Integer.parse(patch)
        "#{major}.#{minor}.#{patch_num + 1}"

      _ ->
        # Fallback for non-standard versions
        "#{version}.1"
    end
  end

  ## Private Validation Helpers

  defp validate_preferences(changeset) do
    preferences = get_field(changeset, :preferences)

    if preferences && is_map(preferences) do
      # Validate common preference keys
      validate_common_preferences(changeset, preferences)
    else
      add_error(changeset, :preferences, "must be a map")
    end
  end

  defp validate_common_preferences(changeset, preferences) do
    changeset
    |> validate_theme(preferences["theme"])
    |> validate_language(preferences["language"])
    |> validate_notifications(preferences["notifications"])
  end

  defp validate_theme(changeset, theme) when theme in [nil, "light", "dark", "auto"] do
    changeset
  end

  defp validate_theme(changeset, theme) do
    add_error(
      changeset,
      :preferences,
      "theme must be one of: light, dark, auto, got: #{inspect(theme)}"
    )
  end

  defp validate_language(changeset, language)
       when language in [nil, "en", "es", "fr", "de", "zh", "ja"] do
    changeset
  end

  defp validate_language(changeset, language) do
    add_error(changeset, :preferences, "unsupported language: #{inspect(language)}")
  end

  defp validate_notifications(changeset, notifications)
       when is_map(notifications) or is_nil(notifications) do
    if notifications do
      validate_notification_keys(changeset, notifications)
    else
      changeset
    end
  end

  defp validate_notifications(changeset, notifications) do
    add_error(
      changeset,
      :preferences,
      "notifications must be a map, got: #{inspect(notifications)}"
    )
  end

  defp validate_notification_keys(changeset, notifications) do
    valid_keys = ["email", "push", "sms", "in_app"]
    invalid_keys = Map.keys(notifications) -- valid_keys

    if Enum.empty?(invalid_keys) do
      # Also validate that values are booleans
      validate_notification_values(changeset, notifications)
    else
      add_error(
        changeset,
        :preferences,
        "invalid notification keys: #{Enum.join(invalid_keys, ", ")}"
      )
    end
  end

  defp validate_notification_values(changeset, notifications) do
    invalid_values =
      Enum.filter(notifications, fn {_key, value} ->
        not is_boolean(value)
      end)

    if Enum.empty?(invalid_values) do
      changeset
    else
      invalid_keys = Enum.map(invalid_values, fn {key, _value} -> key end)

      add_error(
        changeset,
        :preferences,
        "notification values must be booleans for keys: #{Enum.join(invalid_keys, ", ")}"
      )
    end
  end

  defp validate_metadata(changeset) do
    metadata = get_field(changeset, :metadata)

    if metadata && is_map(metadata) do
      changeset
    else
      add_error(changeset, :metadata, "must be a map")
    end
  end

  defp validate_embedding(changeset) do
    embedding = get_field(changeset, :embedding)

    if embedding do
      case Pgvector.to_list(embedding) do
        {:ok, list} when length(list) == 1536 ->
          # Additional validation: check that all values are finite numbers
          validate_embedding_values(changeset, list)

        {:ok, list} ->
          add_error(
            changeset,
            :embedding,
            "must be 1536 dimensions (Qodo-Embed-1), got #{length(list)} dimensions"
          )

        {:error, reason} ->
          add_error(changeset, :embedding, "invalid vector format: #{inspect(reason)}")
      end
    else
      changeset
    end
  end

  defp validate_embedding_values(changeset, values) do
    non_finite =
      Enum.filter(values, fn value ->
        not (is_number(value) and is_finite_number?(value))
      end)

    if Enum.empty?(non_finite) do
      changeset
    else
      add_error(
        changeset,
        :embedding,
        "embedding contains non-finite values: #{Enum.take(non_finite, 3) |> Enum.join(", ")}"
      )
    end
  end

  defp is_finite_number?(value) when is_float(value) do
    not (value == :infinity or value == :"-infinity" or is_nan?(value))
  end

  defp is_finite_number?(value) when is_integer(value) do
    true
  end

  defp is_finite_number?(_) do
    false
  end

  defp is_nan?(value) do
    # NaN is the only float that doesn't equal itself
    value != value
  end
end
