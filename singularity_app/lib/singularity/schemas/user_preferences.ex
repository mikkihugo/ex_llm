
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
    |> validate_inclusion(:preference_type, ["general", "ui", "notifications", "privacy", "advanced"])
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
      where: fragment("? ? ?", p.preferences, ^key),
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
    # Get user's preferences
    user_prefs = from p in query, where: p.user_id == ^user_id and p.is_active == true

    # Find similar users by preference similarity
    from p in query,
      where: p.user_id != ^user_id,
      where: p.is_active == true,
      where: not is_nil(p.embedding),
      order_by: fragment("embedding <-> (SELECT embedding FROM user_preferences WHERE user_id = ? AND is_active = true LIMIT 1)", ^user_id),
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
    add_error(changeset, :preferences, "theme must be one of: light, dark, auto, got: #{theme}")
  end

  defp validate_language(changeset, language) when language in [nil, "en", "es", "fr", "de", "zh", "ja"] do
    changeset
  end

  defp validate_language(changeset, language) do
    add_error(changeset, :preferences, "unsupported language: #{language}")
  end

  defp validate_notifications(changeset, notifications) when is_map(notifications) or is_nil(notifications) do
    if notifications do
      validate_notification_keys(changeset, notifications)
    else
      changeset
    end
  end

  defp validate_notifications(changeset, _notifications) do
    add_error(changeset, :preferences, "notifications must be a map")
  end

  defp validate_notification_keys(changeset, notifications) do
    valid_keys = ["email", "push", "sms", "in_app"]
    invalid_keys = Map.keys(notifications) -- valid_keys

    if Enum.empty?(invalid_keys) do
      changeset
    else
      add_error(changeset, :preferences, "invalid notification keys: #{Enum.join(invalid_keys, ", ")}")
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
          changeset

        {:ok, list} ->
          add_error(
            changeset,
            :embedding,
            "must be 1536 dimensions (Qodo-Embed-1), got #{length(list)}"
          )

        {:error, _} ->
          add_error(changeset, :embedding, "invalid vector format")
      end
    else
      changeset
    end
  end
end