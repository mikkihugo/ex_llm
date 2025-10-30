defmodule Singularity.Execution.SPARC.Supervisor do
  @moduledoc """
  SPARC Supervisor - Manages SPARC methodology orchestration.

  SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) is a
  systematic methodology for code generation with quality assurance.

  ## Managed Processes

  - `Singularity.Execution.SPARC.SPARCOrchestrator` - GenServer for template-driven SPARC execution with TaskGraph integration

  ## SPARC Methodology

  The SPARC methodology follows these phases:
  1. **Specification** - Gather requirements and define goals
  2. **Pseudocode** - Create language-agnostic algorithm
  3. **Architecture** - Design system structure
  4. **Refinement** - Iterate and improve
  5. **Completion** - Finalize and validate

  ## Dependencies

  Depends on:
  - LLM.Supervisor - For LLM-driven SPARC phases
  - Knowledge.Supervisor - For template access
  - Singularity.Jobs.PgmqClient.Supervisor - For SPARC workflow coordination
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting SPARC Supervisor...")

    children = [
      Singularity.Execution.SPARC.SPARCOrchestrator
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
