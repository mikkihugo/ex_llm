defmodule Singularity.JobQueue do
  @moduledoc """
  App-facing Job Queue API. Currently delegates to Oban, but gives
  us a stable facade if we later replace Oban.
  """

  @doc """
  Enqueue a job using the given worker module and args.
  The worker module must provide `new/2` as in Oban.Worker.
  """
  @spec enqueue(module(), map(), keyword()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(worker_mod, args, opts \\ []) when is_map(args) do
    changeset = apply(worker_mod, :new, [args, opts])
    Oban.insert(changeset)
  end

  @doc """
  Enqueue multiple jobs at once.
  Each entry should be `{WorkerModule, args, opts}`.
  """
  @spec enqueue_all([{module(), map(), keyword()}]) :: {:ok, [Oban.Job.t()]} | {:error, term()}
  def enqueue_all(entries) when is_list(entries) do
    changesets =
      Enum.map(entries, fn {mod, args, opts} -> apply(mod, :new, [args, opts]) end)

    Oban.insert_all(changesets)
  end

  @doc """
  Insert a prepared Oban changeset.
  """
  @spec insert(Ecto.Changeset.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  defdelegate insert(changeset), to: Oban

  @doc """
  Synchronous insert that raises on error.
  """
  @spec insert!(Ecto.Changeset.t()) :: Oban.Job.t()
  defdelegate insert!(changeset), to: Oban
end
