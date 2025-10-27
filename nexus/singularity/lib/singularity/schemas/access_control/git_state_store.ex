defmodule Singularity.Git.GitStateStore do
  @moduledoc """
  Persistence layer for git coordination state. Stores agent workspaces,
  pending merges, and merge history in PostgreSQL so coordination survives
  restarts and can be queried by other services.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Git.GitStateStore",
    "purpose": "Persists git agent coordination state across restarts",
    "role": "schema",
    "layer": "infrastructure",
    "tables": ["git_agent_sessions", "git_pending_merges", "git_merge_history"],
    "features": ["multi_schema", "upsert_helpers", "coordination_state"]
  }
  ```

  ### Anti-Patterns
  - ❌ DO NOT store in-memory only - use these schemas for persistence
  - ❌ DO NOT manually manage conflicts - use upsert helpers
  - ✅ DO use this for agent workspace coordination
  - ✅ DO use this for merge tracking and history

  ### Search Keywords
  git coordination, agent workspace, merge tracking, pending merges,
  merge history, git state persistence, branch coordination, multi-agent git
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Singularity.Repo

  ## Agent Sessions

  schema "git_agent_sessions" do
    field :agent_id, :string
    field :branch, :string
    field :workspace_path, :string
    field :correlation_id, :string
    field :status, :string, default: "active"
    field :meta, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @required_session_fields ~w(agent_id workspace_path status)a
  @optional_session_fields ~w(branch correlation_id meta)a

  @doc """
  Insert or update an agent session.
  """
  def upsert_session(attrs) when is_map(attrs) do
    attrs = normalize_session_attrs(attrs)

    %__MODULE__{}
    |> cast(attrs, @required_session_fields ++ @optional_session_fields)
    |> validate_required(@required_session_fields)
    |> unique_constraint(:agent_id)
    |> Repo.insert(
      on_conflict:
        {:replace, [:branch, :workspace_path, :correlation_id, :status, :meta, :updated_at]},
      conflict_target: :agent_id
    )
  end

  @doc "Delete agent session by agent id"
  def delete_session(agent_id) do
    Repo.delete_all(from s in __MODULE__, where: s.agent_id == ^normalize_id(agent_id))
  end

  @doc "List all agent sessions"
  def list_sessions do
    Repo.all(__MODULE__)
  end

  ## Pending merges

  defmodule PendingMerge do
    use Ecto.Schema
    import Ecto.Changeset

    schema "git_pending_merges" do
      field :branch, :string
      field :pr_number, :integer
      field :agent_id, :string
      field :task_id, :string
      field :correlation_id, :string
      field :meta, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    @required ~w(branch agent_id)a

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:branch, :pr_number, :agent_id, :task_id, :correlation_id, :meta])
      |> validate_required(@required)
      |> unique_constraint(:branch)
    end
  end

  @doc "Insert or update pending merge info"
  def upsert_pending_merge(attrs) when is_map(attrs) do
    attrs = normalize_pending_attrs(attrs)

    %PendingMerge{}
    |> PendingMerge.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace, [:pr_number, :agent_id, :task_id, :correlation_id, :meta, :updated_at]},
      conflict_target: :branch
    )
  end

  @doc "Remove pending merge by branch"
  def delete_pending_merge(branch) do
    Repo.delete_all(from p in PendingMerge, where: p.branch == ^branch)
  end

  @doc "List pending merges"
  def list_pending_merges do
    Repo.all(PendingMerge)
  end

  ## Merge history

  defmodule MergeHistory do
    use Ecto.Schema
    import Ecto.Changeset

    schema "git_merge_history" do
      field :branch, :string
      field :agent_id, :string
      field :task_id, :string
      field :correlation_id, :string
      field :merge_commit, :string
      field :status, :string
      field :details, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    @required ~w(branch status)a

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :branch,
        :agent_id,
        :task_id,
        :correlation_id,
        :merge_commit,
        :status,
        :details
      ])
      |> validate_required(@required)
    end
  end

  @doc "Record a merge outcome (success, conflict, failure, etc.)"
  def log_merge(attrs) when is_map(attrs) do
    attrs = normalize_merge_attrs(attrs)

    %MergeHistory{}
    |> MergeHistory.changeset(attrs)
    |> Repo.insert()
  end

  ## Normalizers

  defp normalize_session_attrs(attrs) do
    attrs
    |> Map.update(:agent_id, nil, &normalize_id/1)
    |> Map.update(:status, "active", &to_string/1)
    |> Map.update(:meta, %{}, &ensure_map/1)
  end

  defp normalize_pending_attrs(attrs) do
    attrs
    |> Map.update(:agent_id, nil, &normalize_id/1)
    |> Map.update(:meta, %{}, &ensure_map/1)
  end

  defp normalize_merge_attrs(attrs) do
    attrs
    |> Map.update(:agent_id, nil, &normalize_id/1)
    |> Map.update(:status, "unknown", &to_string/1)
    |> Map.update(:details, %{}, &ensure_map/1)
  end

  defp ensure_map(%{} = map), do: map
  defp ensure_map(_), do: %{}

  defp normalize_id(nil), do: nil
  defp normalize_id(id) when is_binary(id), do: id
  defp normalize_id(id) when is_atom(id), do: Atom.to_string(id)
  defp normalize_id(id), do: to_string(id)
end
