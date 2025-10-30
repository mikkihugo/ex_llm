defmodule Singularity.RCA.SessionQueries do
  @moduledoc """
  RCA Session Queries - Answer questions about code generation sessions

  Enables querying the complete lineage of code generation, refinement, and validation.

  ## Questions Answered

  - "Which prompt generated this code?"
  - "How many refinement iterations did it take?"
  - "What's the success rate by template?"
  - "How does agent version affect quality?"
  - "What's the cost distribution across sessions?"
  - "Which agents produce the highest quality code?"
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.RCA.{GenerationSession, RefinementStep}

  @doc """
  Get a generation session with all related data (refinement steps, test results, fixes).
  """
  def get_session_with_all_relations(session_id) do
    GenerationSession
    |> where(id: ^session_id)
    |> preload([:refinement_steps])
    |> Repo.one()
  end

  @doc """
  Get all generation sessions for an agent.
  """
  def sessions_by_agent(agent_id, limit \\ 50) do
    GenerationSession
    |> where(agent_id: ^agent_id)
    |> order_by(desc: :started_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Get all generation sessions using a specific template.
  """
  def sessions_by_template(template_id, limit \\ 50) do
    GenerationSession
    |> where(template_id: ^template_id)
    |> order_by(desc: :started_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Get session success statistics by agent.

  Returns: %{agent_id => %{total: N, successful: N, success_rate: X.X}}
  """
  def success_rate_by_agent do
    GenerationSession
    |> where([gs], gs.status == "completed")
    |> group_by([gs], gs.agent_id)
    |> select([gs], {
      gs.agent_id,
      {
        count(gs.id),
        sum(fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", gs.final_outcome, "success"))
      }
    })
    |> Repo.all()
    |> Enum.map(fn {agent_id, {total, successful}} ->
      {agent_id,
       %{
         total: total,
         successful: successful || 0,
         success_rate:
           if(total > 0, do: ((successful || 0) / total * 100) |> Float.round(2), else: 0.0)
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Get session success statistics by template.

  Returns: %{template_id => %{total: N, successful: N, success_rate: X.X}}
  """
  def success_rate_by_template do
    GenerationSession
    |> where([gs], gs.status == "completed")
    |> group_by([gs], gs.template_id)
    |> select([gs], {
      gs.template_id,
      {
        count(gs.id),
        sum(fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", gs.final_outcome, "success"))
      }
    })
    |> Repo.all()
    |> Enum.map(fn {template_id, {total, successful}} ->
      {template_id,
       %{
         total: total,
         successful: successful || 0,
         success_rate:
           if(total > 0, do: ((successful || 0) / total * 100) |> Float.round(2), else: 0.0)
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Get average cost in tokens by outcome.

  Returns: %{outcome => avg_tokens}
  """
  def average_cost_by_outcome do
    GenerationSession
    |> where([gs], gs.status == "completed")
    |> group_by([gs], gs.final_outcome)
    |> select([gs], {
      gs.final_outcome,
      avg(gs.generation_cost_tokens)
    })
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Get refinement statistics for a session.

  Returns: {total_steps, total_tokens, actions_list}
  """
  def refinement_stats(session_id) do
    RefinementStep
    |> where(generation_session_id: ^session_id)
    |> order_by(asc: :step_number)
    |> Repo.all()
    |> then(fn steps ->
      {
        length(steps),
        Enum.sum(Enum.map(steps, & &1.tokens_used)),
        Enum.map(steps, & &1.agent_action)
      }
    end)
  end

  @doc """
  Get the average number of refinement steps for successful vs failed sessions.

  Returns: %{success: N, failure: N}
  """
  def average_refinement_steps_by_outcome do
    from(gs in GenerationSession,
      left_join: rs in RefinementStep,
      on: rs.generation_session_id == gs.id,
      where: gs.status == "completed",
      group_by: [gs.id, gs.final_outcome],
      select: {gs.final_outcome, count(rs.id)}
    )
    |> Repo.all()
    |> Enum.group_by(fn {outcome, _} -> outcome end, fn {_, count} -> count end)
    |> Enum.map(fn {outcome, counts} ->
      avg_count =
        if Enum.empty?(counts) do
          0
        else
          Enum.sum(counts) / length(counts)
        end

      {outcome, Float.round(avg_count, 2)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Get all sessions by date range.

  Returns ordered list of sessions.
  """
  def sessions_by_date_range(start_datetime, end_datetime, limit \\ 100) do
    GenerationSession
    |> where([gs], gs.started_at >= ^start_datetime and gs.started_at <= ^end_datetime)
    |> order_by(desc: :started_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Get failed sessions for debugging/learning.

  Returns: List of failed sessions with details
  """
  def failed_sessions(limit \\ 50) do
    GenerationSession
    |> where([gs], gs.final_outcome in ["failure_validation", "failure_execution"])
    |> order_by(desc: :completed_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Find sessions that generated code for a specific file.

  Returns: List of generation sessions
  """
  def sessions_for_code_file(code_file_id) do
    GenerationSession
    |> where(final_code_file_id: ^code_file_id)
    |> order_by(desc: :completed_at)
    |> Repo.all()
  end

  @doc """
  Get most expensive sessions (by token cost).

  Returns: List of sessions sorted by cost descending
  """
  def most_expensive_sessions(limit \\ 20) do
    GenerationSession
    |> order_by([gs], desc: gs.generation_cost_tokens)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Analyze a session in detail for learning purposes.

  Returns comprehensive analysis structure.
  """
  def analyze_session(session_id) do
    session = get_session_with_all_relations(session_id)
    {refinement_steps, refinement_tokens, actions} = refinement_stats(session_id)

    %{
      session_id: session.id,
      agent_id: session.agent_id,
      agent_version: session.agent_version,
      status: session.status,
      outcome: session.final_outcome,
      duration_seconds:
        if session.started_at && session.completed_at do
          DateTime.diff(session.completed_at, session.started_at)
        else
          nil
        end,
      generation_cost_tokens: session.generation_cost_tokens,
      validation_cost_tokens: session.total_validation_cost_tokens,
      total_cost_tokens: session.generation_cost_tokens + session.total_validation_cost_tokens,
      refinement_analysis: %{
        total_steps: refinement_steps,
        total_tokens: refinement_tokens,
        actions_taken: actions,
        avg_tokens_per_step:
          if(refinement_steps > 0, do: refinement_tokens / refinement_steps, else: 0)
      },
      quality_metrics: session.success_metrics || %{}
    }
  end
end
