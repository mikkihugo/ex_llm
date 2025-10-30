defmodule Singularity.Workflows.CodebaseRegistrySyncWorkflow do
  @moduledoc """
  QuantumFlow workflow that runs a full codebase analysis and persists the snapshot
  via `Singularity.CodebaseRegistry`.
  """

  alias Singularity.CodeAnalysis.Runner
  alias Singularity.CodebaseRegistry

  @default_codebase Application.compile_env(:singularity, :codebase_id, "singularity")

  @spec __workflow_steps__() :: list()
  def __workflow_steps__ do
    [
      {:prepare_context, &__MODULE__.prepare_context/1},
      {:run_analysis, &__MODULE__.run_analysis/1, depends_on: [:prepare_context]},
      {:persist_snapshot, &__MODULE__.persist_snapshot/1, depends_on: [:run_analysis]}
    ]
  end

  def prepare_context(input) do
    codebase_id =
      input
      |> fetch_key(:codebase_id, @default_codebase)

    snapshot_id =
      input
      |> fetch_key(:snapshot_id, DateTime.utc_now() |> DateTime.to_unix(:millisecond))

    timestamp = DateTime.utc_now()

    {:ok,
     %{
       codebase_id: codebase_id,
       snapshot_id: snapshot_id,
       analysis_timestamp: timestamp
     }}
  end

  def run_analysis(state) do
    context = step_result(state, :prepare_context)
    codebase_id = fetch_key(context, :codebase_id)

    case Runner.run(codebase_id) do
      {:ok, snapshot} ->
        {:ok, snapshot}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def persist_snapshot(state) do
    context = step_result(state, :prepare_context)
    analysis = step_result(state, :run_analysis)

    snapshot_attrs =
      analysis
      |> Map.put(:codebase_id, fetch_key(context, :codebase_id))
      |> Map.put(:snapshot_id, fetch_key(context, :snapshot_id))
      |> Map.put(:analysis_timestamp, fetch_key(context, :analysis_timestamp))

    case CodebaseRegistry.upsert_snapshot(snapshot_attrs) do
      {:ok, record} ->
        {:ok,
         %{
           status: :persisted,
           snapshot_id: fetch_key(context, :snapshot_id),
           codebase_id: fetch_key(context, :codebase_id),
           record_id: record.id
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_key(map, key, default \\ nil) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, to_string(key)) -> Map.get(map, to_string(key))
      default == nil -> nil
      true -> default
    end
  end

  defp step_result(state, key) do
    state[to_string(key)] || state[key] || %{}
  end
end
