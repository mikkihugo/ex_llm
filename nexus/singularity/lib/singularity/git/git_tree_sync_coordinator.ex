defmodule Singularity.Git.GitTreeSyncCoordinator do
  @moduledoc """
  Git tree-based coordination for multi-agent development.

  Strategy:
  - Each LLM-powered agent gets own branch
  - Agents work in isolated git workspaces
  - Rule-based agents work on main (no conflicts, no branches needed)
  - Merge coordination handles conflicts and consensus

  This minimizes:
  - LLM calls (only when necessary)
  - Git branches (only for LLM work)
  - Merge conflicts (isolated workspaces)
  """

  use GenServer
  require Logger

  alias Singularity.{Autonomy, Git}
  alias Autonomy.Correlation
  alias Singularity.Git.GitStateStore
  alias Ecto.UUID

  defstruct [
    :repo_path,
    # %{agent_id => workspace_path}
    :agent_workspaces,
    # %{branch_name => agent_id}
    :active_branches,
    # [%{branch, pr_number, agent_id}]
    :pending_merges,
    :base_branch,
    :remote
  ]

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Assign task to agent with git workspace.

  For LLM tasks: Creates branch + workspace
  For rule tasks: No branch needed (direct to main)
  """
  def assign_task(agent_id, task, use_llm: use_llm?) do
    GenServer.call(__MODULE__, {:assign_task, agent_id, task, use_llm?})
  end

  @doc "Submit completed work (creates PR if from branch)"
  def submit_work(agent_id, result) do
    GenServer.call(__MODULE__, {:submit_work, agent_id, result})
  end

  @doc "Get merge status for epic (how many PRs pending)"
  def merge_status(correlation_id) do
    GenServer.call(__MODULE__, {:merge_status, correlation_id})
  end

  @doc "Coordinate merging all PRs for an epic"
  def merge_all_for_epic(correlation_id) do
    GenServer.call(__MODULE__, {:merge_epic, correlation_id}, :infinity)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    repo_path = opts[:repo_path] || "/tmp/singularity-workspace"

    # Ensure workspace exists
    File.mkdir_p!(repo_path)

    # Initialize git repo if needed
    if !File.exists?(Path.join(repo_path, ".git")) do
      System.cmd("git", ["init"], cd: repo_path)
      System.cmd("git", ["commit", "--allow-empty", "-m", "Initial commit"], cd: repo_path)
    end

    sessions = GitStateStore.list_sessions()
    pending_merges = GitStateStore.list_pending_merges()

    state = %__MODULE__{
      repo_path: repo_path,
      agent_workspaces: build_workspace_map(sessions),
      active_branches: build_branch_map(sessions),
      pending_merges: Enum.map(pending_merges, &merge_from_record/1),
      base_branch: opts[:base_branch] || "main",
      remote: Keyword.get(opts, :remote)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:assign_task, agent_id, task, use_llm?}, _from, state) do
    correlation_id = Correlation.current()

    if use_llm? do
      # LLM task - create branch + workspace
      assign_llm_task(agent_id, task, correlation_id, state)
    else
      # Rule-based task - no branch needed
      assign_rule_task(agent_id, task, state)
    end
  end

  @impl true
  def handle_call({:submit_work, agent_id, result}, _from, state) do
    agent_key = normalize_agent_id(agent_id)

    case Map.get(state.active_branches, result.branch) do
      nil ->
        # No branch - was rule-based work, already on main
        {:reply, {:ok, :committed_to_main}, state}

      ^agent_key ->
        # Agent's branch - create PR
        create_pull_request(agent_id, result, state)

      other ->
        Logger.warning("Agent attempted to submit work for branch owned by another agent",
          branch: result.branch,
          requested_by: agent_id,
          owner: other
        )

        {:reply, {:error, :not_owner}, state}
    end
  end

  @impl true
  def handle_call({:merge_status, correlation_id}, _from, state) do
    pending =
      state.pending_merges
      |> Enum.filter(&(&1.correlation_id == correlation_id))

    status = %{
      pending_count: length(pending),
      pending_branches: Enum.map(pending, & &1.branch)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:merge_epic, correlation_id}, _from, state) do
    pending =
      state.pending_merges
      |> Enum.filter(&(&1.correlation_id == correlation_id))

    Logger.info("Merging epic PRs",
      correlation_id: correlation_id,
      pr_count: length(pending)
    )

    # Build dependency graph
    graph = build_dependency_graph(pending, state)

    # Topological sort
    merge_order = topological_sort(graph)

    # Merge in order
    {results, new_state} = merge_in_order(merge_order, pending, state)

    {:reply, {:ok, results}, new_state}
  end

  ## Private Functions

  defp assign_llm_task(agent_id, task, correlation_id, state) do
    # Create branch name
    branch = "feature/agent-#{agent_id}/#{task.id}-#{short_uuid()}"

    # Create agent workspace (clone of repo)
    workspace = Path.join([state.repo_path, "agents", to_string(agent_id)])
    File.mkdir_p!(workspace)

    # Clone repo to workspace if needed
    if !File.exists?(Path.join(workspace, ".git")) do
      System.cmd("git", ["clone", state.repo_path, workspace])
    end

    # Checkout new branch in agent workspace
    System.cmd("git", ["checkout", "-b", branch, state.base_branch], cd: workspace)

    agent_key = normalize_agent_id(agent_id)

    assignment = %{
      agent_id: agent_id,
      task: task,
      branch: branch,
      workspace: workspace,
      correlation_id: correlation_id
    }

    GitStateStore.upsert_session(%{
      agent_id: agent_key,
      branch: branch,
      workspace_path: workspace,
      correlation_id: correlation_id,
      status: "active",
      meta: %{task_id: task.id}
    })

    new_state = %{
      state
      | agent_workspaces: Map.put(state.agent_workspaces, agent_key, workspace),
        active_branches: Map.put(state.active_branches, branch, agent_key)
    }

    Logger.info("Assigned LLM task with branch",
      agent_id: agent_id,
      branch: branch,
      correlation_id: correlation_id
    )

    {:reply, {:ok, assignment}, new_state}
  end

  defp assign_rule_task(agent_id, task, state) do
    # Rule-based work doesn't need branch
    # Just work directly on main in a temp workspace
    workspace = Path.join([state.repo_path, "rule-work", to_string(agent_id)])
    File.mkdir_p!(workspace)

    agent_key = normalize_agent_id(agent_id)

    assignment = %{
      agent_id: agent_id,
      task: task,
      # No branch for rule work
      branch: nil,
      workspace: workspace,
      method: :rules
    }

    GitStateStore.upsert_session(%{
      agent_id: agent_key,
      branch: nil,
      workspace_path: workspace,
      status: "rules",
      meta: %{task_id: task.id}
    })

    {:reply, {:ok, assignment}, state}
  end

  defp create_pull_request(agent_id, result, state) do
    workspace = state.agent_workspaces[agent_id]
    branch = result.branch

    # Commit changes in agent workspace
    System.cmd("git", ["add", "."], cd: workspace)
    System.cmd("git", ["commit", "-m", result.commit_message || "Agent work"], cd: workspace)

    # Push branch
    if state.remote do
      System.cmd("git", ["push", state.remote, branch], cd: workspace)
    end

    # Create PR (using gh CLI or API)
    pr_number = create_pr_via_gh(branch, state.base_branch, result, workspace)

    # Add to pending merges
    agent_key = normalize_agent_id(agent_id)

    pending_merge = %{
      branch: branch,
      pr_number: pr_number,
      agent_id: agent_key,
      task_id: result.task_id,
      correlation_id: result.correlation_id,
      created_at: DateTime.utc_now()
    }

    GitStateStore.upsert_pending_merge(pending_merge)

    new_state = %{state | pending_merges: [pending_merge | state.pending_merges]}

    Logger.info("Created pull request",
      branch: branch,
      pr_number: pr_number,
      agent_id: agent_id
    )

    {:reply, {:ok, pr_number}, new_state}
  end

  defp create_pr_via_gh(branch, base, result, workspace) do
    title = result.pr_title || "Agent-generated code"
    body = result.pr_body || "Automated pull request from agent"

    # Use gh CLI
    case System.cmd(
           "gh",
           [
             "pr",
             "create",
             "--base",
             base,
             "--head",
             branch,
             "--title",
             title,
             "--body",
             body
           ],
           cd: workspace
         ) do
      {output, 0} ->
        # Extract PR number from output
        case Regex.run(~r/#(\d+)/, output) do
          [_, pr_number] -> String.to_integer(pr_number)
          _ -> nil
        end

      {error, _code} ->
        Logger.error("Failed to create PR", error: error)
        nil
    end
  end

  defp build_dependency_graph(prs, state) do
    # Analyze file changes to determine dependencies
    # PR that modifies file A must merge before PR that modifies file A + B

    Enum.reduce(prs, %{}, fn pr, graph ->
      files_changed = get_changed_files(pr.branch, state)

      # Find other PRs that modify overlapping files
      dependencies =
        Enum.filter(prs, fn other_pr ->
          other_pr.pr_number != pr.pr_number and
            files_overlap?(files_changed, get_changed_files(other_pr.branch, state))
        end)
        |> Enum.map(& &1.pr_number)

      Map.put(graph, pr.pr_number, dependencies)
    end)
  end

  defp get_changed_files(branch, state) do
    case System.cmd("git", ["diff", "--name-only", "#{state.base_branch}..#{branch}"],
           cd: state.repo_path
         ) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)

      _ ->
        []
    end
  end

  defp files_overlap?(files1, files2) do
    MapSet.new(files1)
    |> MapSet.intersection(MapSet.new(files2))
    |> MapSet.size() > 0
  end

  defp topological_sort(graph) do
    # Simple topological sort (Kahn's algorithm)
    # Returns list of PR numbers in merge order

    in_degree =
      graph
      |> Enum.reduce(%{}, fn {node, deps}, acc ->
        acc = Map.put_new(acc, node, 0)

        Enum.reduce(deps, acc, fn dep, a ->
          Map.update(a, dep, 1, &(&1 + 1))
        end)
      end)

    queue =
      in_degree
      |> Enum.filter(fn {_node, degree} -> degree == 0 end)
      |> Enum.map(fn {node, _} -> node end)
      |> :queue.from_list()

    do_topological_sort(queue, graph, in_degree, [])
  end

  defp do_topological_sort(queue, graph, in_degree, result) do
    case :queue.out(queue) do
      {{:value, node}, new_queue} ->
        # Add node to result
        new_result = [node | result]

        # Reduce in-degree of neighbors
        neighbors = Map.get(graph, node, [])

        {new_queue, new_in_degree} =
          Enum.reduce(neighbors, {new_queue, in_degree}, fn neighbor, {q, deg} ->
            new_deg = Map.update!(deg, neighbor, &(&1 - 1))

            if new_deg[neighbor] == 0 do
              {:queue.in(neighbor, q), new_deg}
            else
              {q, new_deg}
            end
          end)

        do_topological_sort(new_queue, graph, new_in_degree, new_result)

      {:empty, _} ->
        Enum.reverse(result)
    end
  end

  defp merge_in_order(merge_order, prs, state) do
    Enum.reduce(merge_order, {[], state}, fn pr_number, {results, st} ->
      pr = Enum.find(prs, &(&1.pr_number == pr_number))

      case try_merge(pr, st) do
        {:ok, merge_commit} ->
          Logger.info("Merged PR", pr: pr_number, branch: pr.branch)

          # Remove from pending
          new_state = %{
            st
            | pending_merges: Enum.reject(st.pending_merges, &(&1.pr_number == pr_number)),
              active_branches: Map.delete(st.active_branches, pr.branch),
              agent_workspaces: Map.delete(st.agent_workspaces, pr.agent_id)
          }

          GitStateStore.delete_pending_merge(pr.branch)
          GitStateStore.delete_session(pr.agent_id)

          GitStateStore.log_merge(%{
            branch: pr.branch,
            agent_id: pr.agent_id,
            task_id: pr.task_id,
            correlation_id: pr.correlation_id,
            merge_commit: merge_commit,
            status: "merged"
          })

          {[{:ok, pr_number, merge_commit} | results], new_state}

        {:conflict, files} ->
          Logger.warning("Merge conflict", pr: pr_number, files: files)

          GitStateStore.log_merge(%{
            branch: pr.branch,
            agent_id: pr.agent_id,
            task_id: pr.task_id,
            correlation_id: pr.correlation_id,
            status: "conflict",
            details: %{files: files}
          })

          {[{:conflict, pr_number, files} | results], st}

        {:error, reason} ->
          Logger.error("Merge failed", pr: pr_number, reason: reason)

          GitStateStore.log_merge(%{
            branch: pr.branch,
            agent_id: pr.agent_id,
            task_id: pr.task_id,
            correlation_id: pr.correlation_id,
            status: "error",
            details: %{reason: reason}
          })

          {[{:error, pr_number, reason} | results], st}
      end
    end)
  end

  defp try_merge(pr, state) do
    repo = state.repo_path

    # Ensure base branch checked out and up to date
    System.cmd("git", ["checkout", state.base_branch], cd: repo)

    if state.remote do
      System.cmd("git", ["fetch", state.remote, state.base_branch], cd: repo)
      System.cmd("git", ["reset", "--hard", "#{state.remote}/#{state.base_branch}"], cd: repo)
    end

    case System.cmd("git", ["merge", "--no-ff", pr.branch], cd: repo) do
      {_output, 0} ->
        # Get merge commit
        merge_commit =
          case System.cmd("git", ["rev-parse", "HEAD"], cd: repo) do
            {commit, 0} -> String.trim(commit)
            _ -> nil
          end

        # Push merge result back to remote
        if state.remote do
          System.cmd("git", ["push", state.remote, state.base_branch], cd: repo)
        end

        {:ok, merge_commit}

      {output, _} ->
        if String.contains?(output, "CONFLICT") do
          System.cmd("git", ["merge", "--abort"], cd: repo)
          conflicts = extract_conflict_files(repo)
          {:conflict, conflicts}
        else
          {:error, output}
        end
    end
  end

  defp extract_conflict_files(repo) do
    case System.cmd("git", ["diff", "--name-only", "--diff-filter=U"], cd: repo) do
      {output, 0} -> String.split(output, "\n", trim: true)
      _ -> []
    end
  end

  defp short_uuid do
    UUID.generate() |> String.slice(0..7)
  end

  defp build_workspace_map(sessions) do
    Enum.reduce(sessions, %{}, fn session, acc ->
      Map.put(acc, session.agent_id, session.workspace_path)
    end)
  end

  defp build_branch_map(sessions) do
    sessions
    |> Enum.filter(& &1.branch)
    |> Enum.reduce(%{}, fn session, acc ->
      Map.put(acc, session.branch, session.agent_id)
    end)
  end

  defp merge_from_record(record) do
    %{
      branch: record.branch,
      pr_number: record.pr_number,
      agent_id: record.agent_id,
      task_id: record.task_id,
      correlation_id: record.correlation_id,
      created_at: record.inserted_at
    }
  end

  defp normalize_agent_id(agent_id) when is_binary(agent_id), do: agent_id
  defp normalize_agent_id(agent_id) when is_atom(agent_id), do: Atom.to_string(agent_id)
  defp normalize_agent_id(agent_id), do: to_string(agent_id)
end
