defmodule Singularity.CodebaseRegistry do
  @moduledoc """
  PG-backed registry that stores analysis snapshots for each codebase.

  All snapshot data is persisted through `Singularity.Schemas.CodebaseSnapshot`
  so consumers have a single source of truth without juggling ad-hoc structs.
  """

  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Schemas.CodebaseSnapshot

  @doc """
  Upsert a codebase analysis snapshot.

  Expects a map with:
    * `:codebase_id` (string)
    * `:snapshot_id` (integer)
    * `:metadata` (map)
    * `:summary` (map)
    * optional `:file_reports` (list) – stored inside metadata
    * optional `:detected_technologies` (list of strings)
    * optional `:features` (map)
  """
  @spec upsert_snapshot(map()) :: {:ok, CodebaseSnapshot.t()} | {:error, term()}
  def upsert_snapshot(%{codebase_id: codebase_id, snapshot_id: snapshot_id} = attrs) do
    snapshot_attrs =
      %{
        codebase_id: codebase_id,
        snapshot_id: snapshot_id,
        metadata: build_metadata(attrs),
        summary: build_summary(attrs),
        detected_technologies: build_detected_technologies(attrs),
        features: build_features(attrs)
      }
      |> maybe_put(:inserted_at, Map.get(attrs, :analysis_timestamp))

    params = Map.delete(snapshot_attrs, :analysis_timestamp)
    changeset = CodebaseSnapshot.changeset(%CodebaseSnapshot{}, params)

    case Repo.insert(changeset,
           on_conflict:
             {:replace, [:metadata, :summary, :detected_technologies, :features, :inserted_at]},
           conflict_target: [:codebase_id, :snapshot_id]
         ) do
      {:ok, snapshot} -> {:ok, snapshot}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def upsert_snapshot(_attrs), do: {:error, :invalid_snapshot}

  @doc """
  List recent snapshots for a codebase, newest first.
  """
  @spec list_snapshots(String.t(), non_neg_integer()) :: [CodebaseSnapshot.t()]
  def list_snapshots(codebase_id, limit \\ 10) do
    CodebaseSnapshot
    |> where([s], s.codebase_id == ^codebase_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Fetch the most recent snapshot summary for a codebase.
  """
  @spec latest_summary(String.t()) :: map() | nil
  def latest_summary(codebase_id) do
    from(s in CodebaseSnapshot,
      where: s.codebase_id == ^codebase_id,
      order_by: [desc: s.inserted_at],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> nil
      %CodebaseSnapshot{summary: summary} -> summary
    end
  end

  defp build_metadata(attrs) do
    metadata =
      attrs
      |> Map.get(:metadata, %{})
      |> stringify_keys()
      |> Map.delete("detected_technologies")

    metadata =
      case Map.get(attrs, :file_reports) do
        nil -> metadata
        reports -> Map.put(metadata, "file_reports", stringify_keys(reports))
      end

    case Map.get(attrs, :analysis_timestamp) do
      nil -> metadata
      ts -> Map.put(metadata, "analysis_timestamp", ts)
    end
  end

  defp build_summary(attrs) do
    attrs
    |> Map.get(:summary, %{})
    |> stringify_keys()
  end

  defp build_detected_technologies(attrs) do
    attrs
    |> Map.get(:detected_technologies, [])
    |> Enum.map(&normalize_string/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp build_features(attrs) do
    attrs
    |> Map.get(:features, %{})
    |> stringify_keys()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp stringify_keys(%{} = map) do
    map
    |> Enum.map(fn {key, value} -> {normalize_string(key), stringify_keys(value)} end)
    |> Enum.into(%{})
  end

  defp stringify_keys(list) when is_list(list) do
    Enum.map(list, &stringify_keys/1)
  end

  defp stringify_keys(value), do: value

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value), do: to_string(value)
end
