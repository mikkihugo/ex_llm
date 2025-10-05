defmodule Singularity.SPARC.Coordinator do
  @moduledoc """
  Single SPARC Coordinator - Like HTDAG, one coordinator manages all phases.

  Coordinates the 5 SPARC phases in sequence:
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
  alias Singularity.Planning.HTDAG

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
      coordinators: nil,  # Single coordinator, no sub-coordinators
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

    result = phases
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

  defp start_phase_coordinators do
    %{
      specification: start_coordinator(SpecificationCoordinator),
      pseudocode: start_coordinator(PseudocodeCoordinator),
      architecture: start_coordinator(ArchitectureCoordinator),
      refinement: start_coordinator(RefinementCoordinator),
      completion: start_coordinator(CompletionCoordinator)
    }
  end

  defp start_coordinator(module) do
    {:ok, pid} = module.start_link()
    pid
  end

  defp execute_coordinator(coordinator, phase, context) do
    GenServer.call(coordinator, {:execute, context}, :infinity)
  end
end