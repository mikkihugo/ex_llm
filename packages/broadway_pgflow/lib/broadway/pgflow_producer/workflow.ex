defmodule Broadway.PgflowProducer.Workflow do
  @moduledoc """
  PGFlow workflow implementation for Broadway.PgflowProducer.

  Defines steps for fetching, batching, and yielding messages from a PostgreSQL queue,
  with support for ack/nack updates and stateful resource hint caching (e.g. GPU locks).
  """

  use ExPgflow.Workflow

  alias Broadway.Message
  require Logger

  @doc false
  # Ensure the state includes resource_hints and yielded_job_hints maps
  def init_state(state) when is_map(state) do
    state
    |> Map.put_new(:resource_hints, %{})
    |> Map.put_new(:yielded_job_hints, %{})
  end

  # Workflow steps

  @doc """
  Fetch step: Query the queue for pending jobs, limited by demand.
  """
  def fetch(state) do
    state = init_state(state)

    %{demand: demand, batch_size: batch_size, queue_name: queue_name, resource_hints: _hints} = state

    import Ecto.Query

    query =
      from(j in queue_name,
        where: j.status == "pending",
        order_by: [asc: j.inserted_at],
        limit: ^demand,
        select: %{id: j.id, data: j.data, metadata: j.metadata}
      )

    jobs = repo().all(query)

    next_state = %{state | jobs: jobs, fetched_at: DateTime.utc_now()}

    {:next, :adjust_batch, next_state}
  end

  @doc """
  Adjust batch decision step.
  """
  def adjust_batch(%{jobs: _jobs, batch_size: batch_size, queue_depth: queue_depth, recent_ack_latency: recent_ack_latency} = state) do
    effective_batch_size =
      cond do
        (is_integer(queue_depth) and queue_depth > 5000) or (is_integer(recent_ack_latency) and recent_ack_latency > 200) ->
          max(4, div(batch_size, 2))

        (is_integer(queue_depth) and queue_depth < 1000) and (is_integer(recent_ack_latency) and recent_ack_latency < 50) ->
          min(batch_size * 2, 512)

        true ->
          batch_size
      end

    {:next, :batch, Map.put(state, :effective_batch_size, effective_batch_size)}
  end

  @doc """
  Batch step: Group fetched jobs into Broadway.Messages.
  """
  def batch(%{jobs: jobs, batch_size: batch_size} = state) when length(jobs) > 0 do
    effective_batch_size = Map.get(state, :effective_batch_size, batch_size)

    batches =
      jobs
      |> Enum.chunk_every(effective_batch_size)
      |> Enum.map(fn batch ->
        batch
        |> Enum.map(fn job ->
          %Message{
            data: {job.id, job.data},
            metadata: job.metadata,
            acknowledger: {__MODULE__, job.id}
          }
        end)
      end)

    next_state = %{state | batches: batches}
    {:next, :yield_and_commit, next_state}
  end

  def batch(state), do: {:halt, :no_jobs, state}

  @doc """
  Yield-and-commit step:
  - Build a transaction that attempts to reserve resources (single-step update_all per resource_key)
    and mark selected job rows as `in_progress`. Only when the DB work succeeds do we send messages.
  - After success, cache hint tokens in the workflow state so they can be released on ack/requeue.
  """
  def yield_and_commit(%{batches: batches, workflow_pid: workflow_pid} = state) do
    state = init_state(state)
    producer_pid = Pgflow.Workflow.get_parent(workflow_pid)

    # Flatten messages and attach workflow_pid into metadata
    messages =
      batches
      |> Enum.flat_map(fn batch ->
        Enum.map(batch, fn msg ->
          metadata = Map.put(msg.metadata || %{}, :workflow_pid, workflow_pid)
          %{msg | metadata: metadata}
        end)
      end)

    # Map job ids and resource requirements from state.jobs
    jobs = Map.get(state, :jobs, [])
    job_map = Map.new(jobs, &{&1.id, &1})
    ids = Enum.map(jobs, & &1.id)

    # Determine distinct resource keys required for this batch
    resource_keys =
      jobs
      |> Enum.map(fn j -> Map.get(j.metadata || %{}, :resource_key) end)
      |> Enum.uniq()
      |> Enum.filter(& &1)

    import Ecto.Query

    multi = Ecto.Multi.new()

    # For each distinct resource_key, add a reservation step that performs a single update_all
    # to mark the resource as held. The step returns the token on success.
    multi =
      Enum.reduce(resource_keys, multi, fn resource_key, m ->
        key_str = to_string(resource_key)
        step = String.to_atom("reserve_#{String.replace(key_str, ~r/[^A-Za-z0-9_]/, "_")}")

        # generate a token deterministically for the transaction (will be returned by the run)
        token = generate_token()

        m
        |> Ecto.Multi.run(step, fn repo, _changes ->
          query =
            from(r in "resources",
              where: r.key == ^key_str and r.status == "available",
              update: [set: [status: "held", holder: ^inspect(workflow_pid), token: ^token, locked_at: fragment("NOW()")]]
            )

          case repo.update_all(query, []) do
            {count, _} when count > 0 -> {:ok, token}
            _ -> {:error, {:resource_unavailable, resource_key}}
          end
        end)
      end)

    # Mark jobs in_progress (only those ids)
    multi =
      Ecto.Multi.run(multi, :mark_in_progress, fn repo, _changes ->
        query =
          from(j in dynamic_table_name(),
            where: j.id in ^ids,
            update: [set: [status: ^"in_progress", updated_at: fragment("NOW()")]]
          )

        case repo.update_all(query, []) do
          {count, _} -> {:ok, count}
          other -> {:error, other}
        end
      end)

    # Yield messages as side-effect
    multi =
      Ecto.Multi.run(multi, :yield_messages, fn _repo, _changes ->
        Enum.chunk_every(messages, 50)
        |> Enum.each(fn batch_msgs ->
          send(producer_pid, {:workflow_yield, batch_msgs})
        end)

        {:ok, :ok}
      end)

    case repo().transaction(multi) do
      {:ok, changes} ->
        # Extract reservation tokens from changes and cache in state.resource_hints
        reservation_changes =
          changes
          |> Enum.filter(fn {k, _v} -> Atom.to_string(k) |> String.starts_with?("reserve_") end)

        resource_hints =
          Enum.reduce(reservation_changes, Map.get(state, :resource_hints, %{}), fn {step_key, token}, acc ->
            # derive resource_key back from step_key
            step_name = Atom.to_string(step_key)
            ["reserve", resource_part] = String.split(step_name, "_", parts: 2)
            resource_key = resource_part
            Map.put(acc, resource_key, %{holder: inspect(workflow_pid), token: token, locked_at: DateTime.utc_now()})
          end)

        # Build mapping of job_id -> {resource_key, token} for yielded jobs that requested resources
        yielded_job_hints =
          Enum.reduce(jobs, Map.get(state, :yielded_job_hints, %{}), fn job, acc ->
            case Map.get(job.metadata || %{}, :resource_key) do
              nil -> acc
              rk ->
                key = to_string(rk)
                case Map.get(resource_hints, key) do
                  %{token: token} -> Map.put(acc, job.id, {key, token})
                  _ -> acc
                end
            end
          end)

        new_state =
          state
          |> Map.put(:resource_hints, resource_hints)
          |> Map.put(:yielded_job_hints, yielded_job_hints)
          |> Map.put(:yielded_at, DateTime.utc_now())

        {:next, :wait_acks, new_state}

      {:error, failed_op, reason, _changes_so_far} ->
        Logger.error("yield_and_commit failed (#{failed_op}): #{inspect(reason)}")
        # No messages were sent if reservation or mark failed (transaction rolled back)
        {:halt, {:error, reason}, state}
    end
  end

  @doc """
  Wait for acks: passive step.
  """
  def wait_acks(state), do: {:halt, :waiting, state}

  # Update handlers for ack/nack that release hints as required

  @doc """
  Handle ack: release any held resource hint for this job and mark completed.
  """
  def handle_update(:ack, %{id: job_id}, state) do
    state = init_state(state)

    case Map.get(state.yielded_job_hints, job_id) do
      nil ->
        # No resource held for this job; just mark completed
        update_job_status([%{id: job_id}], "completed")
        {:ok, state}

      {resource_key, token} ->
        # Release resource and mark job completed in a single transaction
        import Ecto.Query

        multi =
          Ecto.Multi.new()
          |> Ecto.Multi.run(:release_resource, fn repo, _ ->
            query =
              from(r in "resources",
                where: r.key == ^resource_key and r.token == ^token,
                update: [set: [status: "available", holder: nil, token: nil, locked_at: nil]]
              )

            case repo.update_all(query, []) do
              {count, _} -> {:ok, count}
              other -> {:error, other}
            end
          end)
          |> Ecto.Multi.run(:mark_completed, fn repo, _ ->
            query =
              from(j in dynamic_table_name(),
                where: j.id == ^job_id,
                update: [set: [status: ^"completed", updated_at: fragment("NOW()")]]
              )

            case repo.update_all(query, []) do
              {count, _} -> {:ok, count}
              other -> {:error, other}
            end
          end)

        case repo().transaction(multi) do
          {:ok, _changes} ->
            new_resource_hints = Map.delete(state.resource_hints, resource_key)
            new_yielded = Map.delete(state.yielded_job_hints, job_id)
            {:ok, %{state | resource_hints: new_resource_hints, yielded_job_hints: new_yielded}}

          {:error, failed_op, reason, _} ->
            Logger.error("ack release failed (#{failed_op}): #{inspect(reason)}")
            {:error, reason, state}
        end
    end
  end

  @doc """
  Handle requeue: release resource hint and mark job failed/requeued.
  Current behavior: always release hint on requeue to avoid stale holds.
  """
  def handle_update(:requeue, %{id: job_id, reason: reason}, state) do
    state = init_state(state)

    case Map.get(state.yielded_job_hints, job_id) do
      nil ->
        update_job_status([%{id: job_id}], "failed", reason)
        {:ok, %{state | retries: Map.get(state, :retries, 0) + 1}}

      {resource_key, token} ->
        import Ecto.Query

        multi =
          Ecto.Multi.new()
          |> Ecto.Multi.run(:release_resource, fn repo, _ ->
            query =
              from(r in "resources",
                where: r.key == ^resource_key and r.token == ^token,
                update: [set: [status: "available", holder: nil, token: nil, locked_at: nil]]
              )

            case repo.update_all(query, []) do
              {count, _} -> {:ok, count}
              other -> {:error, other}
            end
          end)
          |> Ecto.Multi.run(:mark_failed, fn repo, _ ->
            query =
              from(j in dynamic_table_name(),
                where: j.id == ^job_id,
                update: [set: [status: ^"failed", failure_reason: ^reason, updated_at: fragment("NOW()")]]
              )

            case repo.update_all(query, []) do
              {count, _} -> {:ok, count}
              other -> {:error, other}
            end
          end)

        case repo().transaction(multi) do
          {:ok, _changes} ->
            new_resource_hints = Map.delete(state.resource_hints, resource_key)
            new_yielded = Map.delete(state.yielded_job_hints, job_id)
            {:ok, %{state | resource_hints: new_resource_hints, yielded_job_hints: new_yielded, retries: Map.get(state, :retries, 0) + 1}}

          {:error, failed_op, reason, _} ->
            Logger.error("requeue release failed (#{failed_op}): #{inspect(reason)}")
            {:error, reason, state}
        end
    end
  end

  # Public (private to module) helpers for reservation semantics.
  # Note: these helpers are intentionally simple and deterministic.

  # Try to obtain a reservation for resource_key and cache it in the workflow state.
  # Returns {:ok, token, new_state} or {:error, reason, state}
  defp acquire_hint(state, resource_key, opts \\ []) do
    state = init_state(state)
    key_str = to_string(resource_key)
    current_holder = inspect(state.workflow_pid || self())

    # If already held by this workflow, return existing token
    case Map.get(state.resource_hints, key_str) do
      %{holder: holder} = hint when holder == current_holder ->
        {:ok, hint.token, state}

      _ ->
        token = generate_token()

        import Ecto.Query

        query =
          from(r in "resources",
            where: r.key == ^key_str and r.status == "available",
            update: [set: [status: "held", holder: ^inspect(state.workflow_pid || self()), token: ^token, locked_at: fragment("NOW()")]]
          )

        case repo().update_all(query, []) do
          {count, _} when count > 0 ->
            hint = %{holder: inspect(state.workflow_pid || self()), token: token, locked_at: DateTime.utc_now()}
            new_state = Map.put(state, :resource_hints, Map.put(state.resource_hints || %{}, key_str, hint))
            {:ok, token, new_state}

          _ ->
            {:error, :not_available, state}
        end
    end
  end

  # Release a held hint: validate token matches and mark DB row available.
  # Returns {:ok, new_state} | {:error, reason, state}
  defp release_hint(state, resource_key, token) do
    state = init_state(state)
    key_str = to_string(resource_key)

    case Map.get(state.resource_hints, key_str) do
      %{token: ^token} ->
        import Ecto.Query

        query =
          from(r in "resources",
            where: r.key == ^key_str and r.token == ^token,
            update: [set: [status: "available", holder: nil, token: nil, locked_at: nil]]
          )

        case repo().update_all(query, []) do
          {count, _} when count >= 0 ->
            new_state = %{state | resource_hints: Map.delete(state.resource_hints, key_str)}
            {:ok, new_state}

          other ->
            {:error, other, state}
        end

      _ ->
        {:error, :token_mismatch, state}
    end
  end

  # Simple token generator
  defp generate_token do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end

  defp update_job_status(jobs, status, reason \\ nil) do
    import Ecto.Query

    ids = Enum.map(jobs, & &1.id)

    query =
      if reason do
        from(j in dynamic_table_name(),
          where: j.id in ^ids,
          update: [set: [status: ^status, updated_at: fragment("NOW()"), failure_reason: ^reason]]
        )
      else
        from(j in dynamic_table_name(),
          where: j.id in ^ids,
          update: [set: [status: ^status, updated_at: fragment("NOW()")]]
        )
      end

    repo().update_all(query, [])
  end

  defp dynamic_table_name, do: "embedding_jobs"

  defp repo do
    Application.get_env(:broadway_pgflow, :repo, Singularity.Repo)
  end
end