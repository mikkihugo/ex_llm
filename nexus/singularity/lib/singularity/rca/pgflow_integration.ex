defmodule Singularity.RCA.QuantumFlowIntegration do
  @moduledoc """
  RCA + QuantumFlow Integration - Tracks workflow execution within RCA sessions

  Enables RCA system to understand which QuantumFlow workflows are used in code generation
  and record their execution metrics for learning.

  ## Lifecycle Integration

  ```
  GenerationSession started
    ↓
  QuantumFlow workflow begins (LlmRequest, CodeQualityImprovement, etc.)
    ↓
  track_workflow_start/2 - Record workflow ID in session
    ↓
  Workflow executes steps
    ↓
  record_workflow_step/4 - Track each step as RefinementStep
    ↓
  record_workflow_completion/3 - Update session with workflow outcome
    ↓
  RCA Session complete
  ```

  ## Usage

  ```elixir
  alias Singularity.RCA.QuantumFlowIntegration

  # 1. Start tracking a workflow in an RCA session
  {:ok, session} = Singularity.RCA.SessionManager.start_session(%{
    initial_prompt: "Improve code quality",
    agent_id: "quality-agent"
  })

  # 2. When workflow begins
  {:ok, updated} = QuantumFlowIntegration.track_workflow_start(
    session.id,
    "Singularity.Workflows.CodeQualityImprovement"
  )

  # 3. Record each workflow step as refinement step
  {:ok, step} = QuantumFlowIntegration.record_workflow_step(
    session.id,
    1,
    "analyze_metrics",
    "Analyzing code quality metrics"
  )

  # 4. When workflow completes
  {:ok, final} = QuantumFlowIntegration.record_workflow_completion(
    session.id,
    "success",
    %{"improvements" => 42}
  )
  ```

  ## Enabling Workflow Learning

  The RCA system can now learn from workflow patterns:

  ```elixir
  # Which workflows are most effective?
  Singularity.RCA.SessionQueries.success_rate_by_workflow()

  # Which workflow steps are most impactful?
  Singularity.RCA.FailureAnalysis.analyze_workflow_steps()

  # What's the optimal workflow pattern?
  Singularity.RCA.LearningQueries.optimal_workflow_depth()
  ```
  """

  require Logger
  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.RCA.{GenerationSession, RefinementStep}

  @doc """
  Track the start of a QuantumFlow workflow within an RCA session.

  Records which workflow is being executed and stores it in the session for later analysis.

  ## Parameters
  - session_id: UUID of the GenerationSession
  - workflow_module: String name of workflow module (e.g. "Singularity.Workflows.CodeQualityImprovement")

  ## Returns
  - {:ok, session} - Updated session with workflow metadata
  - {:error, reason}

  ## Examples

      iex> track_workflow_start(session_id, "Singularity.Workflows.CodeQualityImprovement")
      {:ok, %GenerationSession{...}}
  """
  @spec track_workflow_start(binary(), String.t()) ::
          {:ok, GenerationSession.t()} | {:error, term()}
  def track_workflow_start(session_id, workflow_module) do
    with {:ok, session} <- Repo.fetch(GenerationSession, session_id) do
      # Store workflow info in success_metrics (can expand to dedicated field later)
      metrics = session.success_metrics || %{}

      session
      |> Ecto.Changeset.change(%{
        success_metrics: Map.put(metrics, "workflow_module", workflow_module)
      })
      |> Repo.update()
    end
  end

  @doc """
  Record a single step of QuantumFlow workflow execution.

  Each workflow step becomes a RefinementStep for learning about which steps are effective.

  ## Parameters
  - session_id: UUID of the GenerationSession
  - step_number: Integer step number within this workflow
  - step_name: String name of workflow step (e.g. "analyze_metrics", "apply_fixes")
  - feedback: String description of what happened in this step
  - opts: Optional options including:
    - :tokens_used - Tokens spent in this step
    - :result - Step result/outcome
    - :metrics - Metrics from this step

  ## Returns
  - {:ok, refinement_step} - Created RefinementStep
  - {:error, reason}

  ## Examples

      iex> record_workflow_step(session_id, 1, "analyze_metrics", "Analyzed 45 metrics")
      {:ok, %RefinementStep{...}}

      iex> record_workflow_step(session_id, 2, "apply_fixes", "Applied 12 fixes", tokens_used: 500)
      {:ok, %RefinementStep{...}}
  """
  @spec record_workflow_step(binary(), integer(), String.t(), String.t(), keyword()) ::
          {:ok, RefinementStep.t()} | {:error, term()}
  def record_workflow_step(session_id, step_number, step_name, feedback, opts \\ []) do
    tokens = Keyword.get(opts, :tokens_used, 0)
    result = Keyword.get(opts, :result)
    metrics = Keyword.get(opts, :metrics, %{})

    validation_details =
      metrics
      |> Map.put("workflow_step", step_name)
      |> Map.put("step_result", result)

    %RefinementStep{
      generation_session_id: session_id,
      step_number: step_number,
      agent_action: "workflow_#{step_name}",
      feedback_received: feedback,
      validation_details: validation_details,
      tokens_used: tokens
    }
    |> Repo.insert()
  end

  @doc """
  Record workflow completion and update session outcome.

  Finalizes the RCA session with workflow results.

  ## Parameters
  - session_id: UUID of the GenerationSession
  - outcome: String outcome ("success", "failure_validation", "failure_execution")
  - workflow_metrics: Map of workflow results and metrics

  ## Returns
  - {:ok, session} - Updated session
  - {:error, reason}

  ## Examples

      iex> record_workflow_completion(session_id, "success", %{"improvements" => 42})
      {:ok, %GenerationSession{...}}
  """
  @spec record_workflow_completion(binary(), String.t(), map()) ::
          {:ok, GenerationSession.t()} | {:error, term()}
  def record_workflow_completion(session_id, outcome, workflow_metrics \\ %{}) do
    with {:ok, session} <- Repo.fetch(GenerationSession, session_id) do
      # Merge workflow metrics with existing success_metrics
      metrics = session.success_metrics || %{}
      merged_metrics = Map.merge(metrics, workflow_metrics)

      session
      |> Ecto.Changeset.change(%{
        final_outcome: outcome,
        success_metrics: merged_metrics,
        status: "completed",
        completed_at: DateTime.utc_now(:microsecond)
      })
      |> Repo.update()
    end
  end

  @doc """
  Get all RCA sessions for a specific workflow.

  Enables analysis of which workflows produce best results.

  ## Parameters
  - workflow_module: String name of workflow module

  ## Returns
  - List of GenerationSession records that used this workflow
  """
  @spec sessions_for_workflow(String.t()) :: [GenerationSession.t()]
  def sessions_for_workflow(workflow_module) do
    from(gs in GenerationSession,
      where: fragment("? ->> ? = ?", gs.success_metrics, "workflow_module", ^workflow_module),
      order_by: [desc: :completed_at]
    )
    |> Repo.all()
  end

  @doc """
  Analyze workflow step effectiveness.

  Shows which workflow steps are most impactful (successful).

  ## Returns
  Map with step analysis:
  ```
  %{
    "analyze_metrics" => %{
      total_uses: 150,
      successful: 145,
      success_rate: 96.67,
      avg_tokens: 450,
      avg_improvement: 3.2
    }
  }
  ```
  """
  @spec analyze_workflow_steps() :: map()
  def analyze_workflow_steps do
    RefinementStep
    |> where([rs], fragment("? LIKE ?", rs.agent_action, "workflow_%"))
    |> select([rs], {
      rs.agent_action,
      count(rs.id),
      sum(fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", rs.validation_result, "pass")),
      avg(rs.tokens_used)
    })
    |> group_by([rs], rs.agent_action)
    |> Repo.all()
    |> Enum.map(fn {action, total, successful, avg_tokens} ->
      step_name = String.replace_prefix(action, "workflow_", "")

      {step_name,
       %{
         total_uses: total,
         successful: successful || 0,
         success_rate:
           if(total > 0,
             do: Float.round((successful || 0) / total * 100, 2),
             else: 0.0
           ),
         avg_tokens: avg_tokens || 0
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Get optimal workflow execution pattern.

  Analyzes successful vs failed workflows to recommend best patterns.

  ## Returns
  Map with recommendations:
  ```
  %{
    "success" => %{
      avg_steps: 3.2,
      most_common_steps: ["analyze_metrics", "apply_fixes", "validate"],
      avg_total_tokens: 1500
    },
    "failure" => %{
      avg_steps: 4.1,
      most_common_steps: ["analyze_metrics", "apply_fixes", "validate", "retry"],
      avg_total_tokens: 2300
    }
  }
  ```
  """
  @spec analyze_workflow_patterns() :: map()
  def analyze_workflow_patterns do
    from(gs in GenerationSession,
      left_join: rs in RefinementStep,
      on: rs.generation_session_id == gs.id,
      where: not is_nil(gs.final_outcome),
      group_by: [gs.id, gs.final_outcome],
      select: {gs.final_outcome, count(rs.id)}
    )
    |> Repo.all()
    |> Enum.group_by(fn {outcome, _} -> outcome end, fn {_, count} -> count end)
    |> Enum.into(%{}, fn {outcome, counts} ->
      avg_steps = if Enum.empty?(counts), do: 0, else: Enum.sum(counts) / length(counts)

      {outcome,
       %{
         avg_steps: Float.round(avg_steps, 2),
         min_steps: Enum.min(counts, fn -> 0 end),
         max_steps: Enum.max(counts, fn -> 0 end)
       }}
    end)
  end

  @doc """
  Check if workflow execution was successful.

  ## Parameters
  - session_id: UUID of the GenerationSession

  ## Returns
  - true if final_outcome is "success"
  - false otherwise
  """
  @spec workflow_successful?(binary()) :: boolean()
  def workflow_successful?(session_id) do
    case Repo.get(GenerationSession, session_id) do
      nil -> false
      session -> session.final_outcome == "success"
    end
  end

  @doc """
  Get workflow metrics from a completed session.

  ## Parameters
  - session_id: UUID of the GenerationSession

  ## Returns
  - Map of workflow metrics, or empty map if not found
  """
  @spec get_workflow_metrics(binary()) :: map()
  def get_workflow_metrics(session_id) do
    case Repo.get(GenerationSession, session_id) do
      nil -> %{}
      session -> session.success_metrics || %{}
    end
  end

  @doc """
  Compare performance of different workflows.

  Shows which workflows achieve best success rate.

  ## Parameters
  - limit: Maximum number of workflows to return (default: 20)

  ## Returns
  List of workflows ranked by success rate:
  ```
  [
    %{
      workflow: "Singularity.Workflows.CodeQualityImprovement",
      total_sessions: 150,
      successful: 145,
      success_rate: 96.67,
      avg_cost_tokens: 1500
    }
  ]
  ```
  """
  @spec compare_workflows(integer()) :: [map()]
  def compare_workflows(limit \\ 20) do
    from(gs in GenerationSession,
      where: not is_nil(gs.final_outcome),
      group_by: [fragment("? ->> ?", gs.success_metrics, "workflow_module")],
      select: {
        fragment("? ->> ?", gs.success_metrics, "workflow_module"),
        count(gs.id),
        sum(fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", gs.final_outcome, "success")),
        avg(gs.generation_cost_tokens)
      },
      order_by: [
        desc:
          fragment(
            "CAST(SUM(CASE WHEN ? = ? THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)",
            gs.final_outcome,
            "success"
          )
      ],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.map(fn {workflow, total, successful, avg_cost} ->
      %{
        workflow: workflow,
        total_sessions: total,
        successful: successful || 0,
        success_rate:
          if(total > 0,
            do: Float.round((successful || 0) / total * 100, 2),
            else: 0.0
          ),
        avg_cost_tokens: avg_cost || 0
      }
    end)
  end
end
