defmodule Singularity.CodebaseRegistry do
  @moduledoc """
  Thin abstraction over analysis tables so every codebase snapshot is tracked
  consistently. Downstream consumers get a single API, while data stays in
  Postgres.
  """

  import Ecto.Query

  alias Singularity.{Repo, Analysis.Metadata, Analysis.FileReport, Analysis.Summary}

  @doc "Register or update snapshot metadata"
  def upsert_snapshot(attrs) when is_map(attrs) do
    Repo.insert!(Metadata.changeset(%Metadata{}, attrs),
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:codebase_id, :snapshot_id]
    )
  end

  @doc "Store file-level analysis records"
  def insert_file_reports(codebase_id, snapshot_id, reports) when is_list(reports) do
    reports
    |> Enum.map(&Map.merge(&1, %{codebase_id: codebase_id, snapshot_id: snapshot_id}))
    |> Enum.chunk_every(500)
    |> Enum.each(fn chunk ->
      Repo.insert_all(FileReport, chunk,
        on_conflict: :replace_all,
        conflict_target: [:codebase_id, :snapshot_id, :path]
      )
    end)
  end

  @doc "Persist snapshot summary"
  def upsert_summary(codebase_id, snapshot_id, attrs) do
    base = %{codebase_id: codebase_id, snapshot_id: snapshot_id}

    Repo.insert!(Summary.changeset(%Summary{}, Map.merge(base, attrs)),
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:codebase_id, :snapshot_id]
    )
  end

  @doc "List recent snapshots"
  def list_snapshots(codebase_id, limit \\ 10) do
    Metadata
    |> where([m], m.codebase_id == ^codebase_id)
    |> order_by([desc: :inserted_at])
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Fetch most recent snapshot summary"
  def latest_summary(codebase_id) do
    Summary
    |> where([s], s.codebase_id == ^codebase_id)
    |> order_by([desc: :updated_at])
    |> limit(1)
    |> Repo.one()
  end
end
