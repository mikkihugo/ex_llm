defmodule Singularity.SPARC.Orchestrator do
  @moduledoc """
  SPARC Orchestrator - Coordinates multiple agents through SPARC phases.

  Orchestrates the 5 SPARC phases in sequence:
  1. Specification - Defines WHAT to build
  2. Pseudocode - Defines HOW in plain language
  3. Architecture - Designs system STRUCTURE
  4. Refinement - OPTIMIZES the design
  5. Completion - Generates FINAL code

  Each phase:
  - Loads templates from tool_doc_index
  - Gathers RAG context
  - Generates phase output
  - Validates quality
  - Passes context to next phase
  """

  use GenServer
  require Logger

  alias Singularity.{TechnologyTemplateLoader, RAGCodeGenerator}

  defstruct [
    :current_phase,
    :task,
    :context,
    :phases_completed,
    :artifacts,
    :coordinators,
    :status
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Execute full SPARC workflow with all 5 coordinators
  """
  def execute(task, opts \\ []) do
    GenServer.call(__MODULE__, {:execute, task, opts}, :infinity)
  end

  @doc """
  Execute a specific phase only
  """
  def execute_phase(phase, task, context \\ %{}) do
    GenServer.call(__MODULE__, {:execute_phase, phase, task, context})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      current_phase: nil,
      task: nil,
      context: %{},
      phases_completed: [],
      artifacts: %{},
      # Single coordinator, no sub-coordinators
      coordinators: nil,
      status: :ready
    }

    Logger.info("SPARC Coordinator initialized - single execution coordinator")
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, task, opts}, _from, state) do
    Logger.info("Starting SPARC execution for: #{inspect(task)}")

    # Initialize context
    context = %{
      task: task,
      language: Keyword.get(opts, :language, "elixir"),
      repo: Keyword.get(opts, :repo),
      quality_level: Keyword.get(opts, :quality, :production),
      started_at: DateTime.utc_now()
    }

    # Run through all 5 phases sequentially
    phases = [:specification, :pseudocode, :architecture, :refinement, :completion]

    result =
      phases
      |> Enum.reduce({:ok, context}, fn phase, {:ok, ctx} ->
        Logger.info("SPARC Phase: #{phase}")
        execute_phase_internal(phase, ctx, state)
      end)

    case result do
      {:ok, final_context} ->
        {:reply, {:ok, final_context.artifacts}, %{state | status: :completed}}

      {:error, reason} ->
        {:reply, {:error, reason}, %{state | status: :failed}}
    end
  end

  @impl true
  def handle_call({:execute_phase, phase, task, context}, _from, state) do
    coordinator = Map.get(state.coordinators, phase)

    case execute_coordinator(coordinator, phase, Map.put(context, :task, task)) do
      {:ok, updated_context} ->
        {:reply, {:ok, updated_context}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private Functions

  defp execute_phase_internal(phase, context, _state) do
    Logger.info("Executing SPARC phase: #{phase}")

    # Load phase-specific templates
    templates = TechnologyTemplateLoader.templates_for_phase(phase)

    # Gather RAG context for this phase
    rag_context = RAGCodeGenerator.gather_context(context.task, phase: phase)

    # Generate phase output using templates + RAG
    phase_context =
      Map.merge(context, %{
        phase: phase,
        templates: templates,
        rag_context: rag_context
      })

    case generate_phase_output(phase, phase_context) do
      {:ok, output} ->
        # Validate quality
        case validate_phase_output(phase, output) do
          :ok ->
            # Update context with phase results
            updated_artifacts = Map.put(context.artifacts || %{}, phase, output)
            completion_key = "#{phase}_completed_at"

            updated_context =
              context
              |> Map.put(:artifacts, updated_artifacts)
              |> Map.put(completion_key, DateTime.utc_now())

            {:ok, updated_context}

          {:error, validation_errors} ->
            {:error, "Phase #{phase} validation failed: #{inspect(validation_errors)}"}
        end

      {:error, reason} ->
        {:error, "Phase #{phase} generation failed: #{reason}"}
    end
  end

  defp generate_phase_output(phase, context) do
    # This would integrate with LLM providers to generate phase-specific output
    # For now, return a placeholder
    {:ok, "Phase #{phase} output for task: #{context.task}"}
  end

  defp validate_phase_output(_phase, _output) do
    # Quality validation logic would go here
    :ok
  end

  defp execute_coordinator(coordinator, _phase, context) do
    GenServer.call(coordinator, {:execute, context}, :infinity)
  end
end
