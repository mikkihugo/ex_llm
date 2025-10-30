defmodule Singularity.RCA.SessionManager do
  @moduledoc """
  RCA Session Manager - Manages generation session lifecycle for self-evolution learning

  Integrates with LLM.Service to track every code generation attempt from prompt to outcome.

  ## Lifecycle

  1. **Start Session**: Create GenerationSession when LLM call begins
  2. **Track Progress**: Record refinement steps as agent iterates
  3. **Record Validation**: Save test execution results
  4. **Complete Session**: Update with final outcome and metrics
  5. **Learn**: Extract patterns for self-improvement

  ## Usage

  ```elixir
  # Start a new session for code generation
  {:ok, session} = SessionManager.start_session(%{
    initial_prompt: "Generate an HTTP server",
    agent_id: "code-gen-v2",
    template_id: "template-123"
  })

  # Session is now tracked and ready for refinement steps
  session_id = session.id

  # Later, when generation completes:
  {:ok, updated_session} = SessionManager.complete_session(session_id, %{
    final_outcome: "success",
    success_metrics: %{
      code_quality: 95,
      test_pass_rate: 100,
      complexity: "medium"
    }
  })
  ```
  """

  require Logger
  alias Singularity.Repo
  alias Singularity.Schemas.RCA.GenerationSession

  @doc """
  Start a new generation session.

  Creates a GenerationSession record to track code generation from start to finish.

  ## Parameters
  - attrs: Map with:
    - :initial_prompt (required) - The user's initial request
    - :agent_id (required) - Which agent is handling this
    - :template_id - Optional template being used
    - :agent_version - Optional agent version (default: "v1.0.0")
    - :parent_session_id - Optional parent session for multi-step tasks

  ## Returns
  - {:ok, session} - Created GenerationSession
  - {:error, changeset} - Validation failed
  """
  @spec start_session(map()) :: {:ok, GenerationSession.t()} | {:error, Ecto.Changeset.t()}
  def start_session(attrs) do
    attrs =
      attrs
      |> Map.put_new(:status, "in_progress")
      |> Map.put_new(:started_at, DateTime.utc_now(:microsecond))

    %GenerationSession{}
    |> GenerationSession.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Complete a generation session with final outcome.

  Updates session with final outcome, success metrics, and cost information.

  ## Parameters
  - session_id: UUID of the GenerationSession
  - outcome_attrs: Map with:
    - :final_outcome - "success", "failure_validation", "failure_execution"
    - :success_metrics - Map of quality metrics (optional)
    - :failure_reason - Reason if failed (optional)
    - :final_code_file_id - Link to generated code file (optional)
    - :generation_cost_tokens - Tokens spent in generation
    - :total_validation_cost_tokens - Tokens spent in validation

  ## Returns
  - {:ok, session} - Updated GenerationSession
  - {:error, reason} - Update failed
  """
  @spec complete_session(binary(), map()) ::
          {:ok, GenerationSession.t()} | {:error, term()}
  def complete_session(session_id, outcome_attrs) do
    with {:ok, session} <- Repo.fetch(GenerationSession, session_id) do
      attrs =
        outcome_attrs
        |> Map.put(:status, "completed")
        |> Map.put(:completed_at, DateTime.utc_now(:microsecond))

      session
      |> GenerationSession.complete_changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Record an LLM call as part of a session.

  Creates link between a GenerationSession and its initial LLM call.

  ## Parameters
  - session_id: UUID of the GenerationSession
  - llm_call_id: UUID of the LLM call record
  """
  @spec record_llm_call(binary(), binary()) :: {:ok, GenerationSession.t()} | {:error, term()}
  def record_llm_call(session_id, llm_call_id) do
    with {:ok, session} <- Repo.fetch(GenerationSession, session_id) do
      session
      |> Ecto.Changeset.change(%{initial_llm_call_id: llm_call_id})
      |> Repo.update()
    end
  end

  @doc """
  Get session with all related data.

  Preloads refinement_steps, test_executions, and fix_applications for analysis.

  ## Parameters
  - session_id: UUID of the GenerationSession

  ## Returns
  - {:ok, session} - Session with all relations loaded
  - {:error, :not_found}
  """
  @spec get_session_full(binary()) :: {:ok, GenerationSession.t()} | {:error, atom()}
  def get_session_full(session_id) do
    case Repo.get(GenerationSession, session_id) do
      nil ->
        {:error, :not_found}

      session ->
        {:ok,
         Repo.preload(session, [
           :refinement_steps,
           :test_executions,
           :fix_applications
         ])}
    end
  end

  @doc """
  Get or create a session from options.

  If generation_session_id is provided in opts, returns existing session.
  Otherwise creates a new session.

  ## Parameters
  - opts: Options containing optional :generation_session_id
  - session_attrs: Attributes for new session if creating

  ## Returns
  - {:ok, session_id} - UUID of session to use for this generation
  - {:error, reason}
  """
  @spec get_or_create_session(keyword(), map()) ::
          {:ok, binary()} | {:error, term()}
  def get_or_create_session(opts, session_attrs \\ %{}) do
    case Keyword.get(opts, :generation_session_id) do
      nil ->
        # Create new session
        case start_session(session_attrs) do
          {:ok, session} -> {:ok, session.id}
          error -> error
        end

      session_id ->
        # Use existing session
        {:ok, session_id}
    end
  end

  @doc """
  Record RCA metrics for a session after generation completes.

  Updates session with token costs and starts analysis for learning.

  ## Parameters
  - session_id: UUID of the GenerationSession
  - llm_response: Response from LLM.Service.call/3
  """
  @spec record_generation_metrics(binary(), map()) ::
          {:ok, GenerationSession.t()} | {:error, term()}
  def record_generation_metrics(session_id, llm_response) do
    with {:ok, session} <- Repo.fetch(GenerationSession, session_id) do
      tokens_used = Map.get(llm_response, :tokens_used, 0)
      cost_cents = Map.get(llm_response, :cost_cents, 0)

      session
      |> Ecto.Changeset.change(%{
        generation_cost_tokens: tokens_used,
        success_metrics: Map.get(llm_response, :metrics, %{})
      })
      |> Repo.update()
    end
  end

  @doc """
  Check if session was successful.

  ## Parameters
  - session_id: UUID of the GenerationSession

  ## Returns
  - true if final_outcome is "success"
  - false otherwise
  """
  @spec successful?(binary()) :: boolean()
  def successful?(session_id) do
    case Repo.get(GenerationSession, session_id) do
      nil -> false
      session -> session.final_outcome == "success"
    end
  end

  @doc """
  Get total cost for a session (generation + validation).

  ## Parameters
  - session_id: UUID of the GenerationSession

  ## Returns
  - integer total tokens used
  """
  @spec total_cost_tokens(binary()) :: non_neg_integer()
  def total_cost_tokens(session_id) do
    case Repo.get(GenerationSession, session_id) do
      nil ->
        0

      session ->
        (session.generation_cost_tokens || 0) +
          (session.total_validation_cost_tokens || 0)
    end
  end
end
