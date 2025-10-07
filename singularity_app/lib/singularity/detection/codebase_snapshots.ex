defmodule Singularity.CodebaseSnapshots do
  @moduledoc """
  Persistence helpers for technology detection snapshots stored in the
  `codebase_snapshots` hypertable. Provides convenience wrappers around
  Ecto so other modules can upsert detections without worrying about
  conflict options or casting.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Singularity.Repo

  @required_fields ~w(codebase_id snapshot_id)a
  @optional_fields ~w(metadata summary detected_technologies features)a

  schema "codebase_snapshots" do
    field :codebase_id, :string
    field :snapshot_id, :integer
    field :metadata, :map, default: %{}
    field :summary, :map, default: %{}
    field :detected_technologies, {:array, :string}, default: []
    field :features, :map, default: %{}

    timestamps(inserted_at: :inserted_at, updated_at: false, type: :utc_datetime_usec)
  end

  @doc """
  Insert or update a snapshot record. Accepts a map with keys matching the
  schema fields. The `metadata`, `summary`, `features`, and
  `detected_technologies` fields default to empty structures if omitted.
  """
  def upsert(attrs) when is_map(attrs) do
    attrs = normalize_attrs(attrs)

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:metadata, :summary, :detected_technologies, :features]},
      conflict_target: [:codebase_id, :snapshot_id]
    )
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  defp normalize_attrs(attrs) do
    attrs
    |> Map.update(:metadata, %{}, &ensure_map/1)
    |> Map.update(:summary, %{}, &ensure_map/1)
    |> Map.update(:features, %{}, &ensure_map/1)
    |> Map.update(:detected_technologies, [], &ensure_string_list/1)
  end

  defp ensure_map(data) when is_map(data), do: data
  defp ensure_map(data) when is_list(data), do: Enum.into(data, %{})
  defp ensure_map(data) when is_nil(data), do: %{}
  defp ensure_map(_), do: %{}

  defp ensure_string_list(data) when is_list(data) do
    data
    |> Enum.map(fn
      item when is_binary(item) -> item
      item when is_atom(item) -> Atom.to_string(item)
      item -> to_string(item)
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp ensure_string_list(data) when is_binary(data), do: [data]
  defp ensure_string_list(data) when is_atom(data), do: [Atom.to_string(data)]
  defp ensure_string_list(data) when is_nil(data), do: []
  defp ensure_string_list(_), do: []
end
