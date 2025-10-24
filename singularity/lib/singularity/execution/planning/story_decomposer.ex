defmodule Singularity.Execution.Planning.StoryDecomposer do
  @moduledoc """
  SPARC Framework Story Decomposer - Systematic user story breakdown via 5-phase LLM methodology.

  Implements the SPARC methodology (Specification, Pseudocode, Architecture, Refinement, Completion)
  to decompose user stories into detailed technical specifications, implementation plans,
  and actionable tasks with fallback mechanisms for LLM reliability.

  ## SPARC Phases (5-State Machine)

  1. **Specification** - Generate detailed technical requirements from user story
  2. **Pseudocode** - Create implementation algorithm logic and data structures
  3. **Architecture** - Design system modules, dependencies, and data flow
  4. **Refinement** - Review, optimize design, and handle edge cases
  5. **Completion** - Generate actionable implementation tasks with priorities

  ## Integration Points

  This module integrates with:
  - `Singularity.LLM.Service` - LLM operations (Service.call_with_script/3 for SPARC phases)
  - SPARC Lua scripts: `templates_data/prompt_library/sparc/decompose-*.lua`
  - PostgreSQL table: `story_decompositions` (stores decomposition results)

  ## Usage

      # Decompose a user story using SPARC
      {:ok, decomposition} = StoryDecomposer.decompose_story(%{
        description: "As a user, I want to authenticate with OAuth2",
        acceptance_criteria: ["User can login with Google", "Session is maintained"]
      })
      # => {:ok, %{specification: "...", pseudocode: "...", architecture: "...", refinement: "...", tasks: [...]}}

      # With complexity control
      {:ok, decomposition} = StoryDecomposer.decompose_story(story, complexity: :high, language: "elixir")

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Planning.StoryDecomposer",
    "purpose": "SPARC 5-phase story decomposition with LLM-driven systematic design",
    "role": "planner",
    "layer": "execution_planning",
    "key_responsibilities": [
      "Decompose user stories into 5 SPARC phases",
      "Generate specifications, pseudocode, architecture, refinement, tasks",
      "Coordinate LLM.Service calls with Lua script templates",
      "Produce actionable implementation tasks with clear requirements"
    ],
    "prevents_duplicates": ["StoryBreakdown", "UserStoryDecomposer", "SPARCOrchestrator"],
    "uses": ["LLM.Service", "Logger"],
    "sparc_phases": ["Specification", "Pseudocode", "Architecture", "Refinement", "Completion"],
    "state_machine": "5-phase linear (spec → pseudo → arch → refine → tasks)"
  }
  ```

  ### Architecture Diagram (Mermaid)

  ```mermaid
  graph TB
    User["User Story<br/>(description + criteria)"] -->|1| Spec["S - Specification<br/>(technical requirements)"]
    Spec -->|2| Pseudo["P - Pseudocode<br/>(algorithm logic)"]
    Pseudo -->|3| Arch["A - Architecture<br/>(modules + data flow)"]
    Arch -->|4| Refine["R - Refinement<br/>(optimize + edge cases)"]
    Refine -->|5| Complete["C - Completion<br/>(actionable tasks)"]

    Spec -->|LLM.Service| LLM["LLM with Lua Scripts"]
    Pseudo -->|LLM.Service| LLM
    Arch -->|LLM.Service| LLM
    Refine -->|LLM.Service| LLM
    Complete -->|LLM.Service| LLM

    Complete -->|Result| Tasks["Implementation Tasks<br/>(prioritized, ready to execute)"]

    style Spec fill:#E8F4F8
    style Pseudo fill:#D0E8F2
    style Arch fill:#B8DCEC
    style Refine fill:#A0D0E6
    style Complete fill:#88C4E0
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.LLM.Service
      function: call_with_script/3
      purpose: Execute SPARC phase Lua scripts for specification, pseudocode, architecture, refinement, tasks
      critical: true
      pattern: "Sequential LLM calls for 5 SPARC phases"
      scripts:
        - "sparc/decompose-specification.lua"
        - "sparc/decompose-pseudocode.lua"
        - "sparc/decompose-architecture.lua"
        - "sparc/decompose-refinement.lua"
        - "sparc/decompose-tasks.lua"

    - module: Logger
      function: error/2
      purpose: Log LLM failures
      critical: false

  called_by:
    - module: Singularity.SPARC.Orchestrator
      function: decompose_story/2
      purpose: Main SPARC orchestrator entry point
      frequency: per_sparc_execution

    - module: Singularity.Agents.PlanningAgent
      function: plan_implementation/1
      purpose: Generate implementation plans from user stories
      frequency: per_planning_request

  state_transitions:
    - name: specification_phase
      from: idle
      to: specification_generated
      trigger: decompose_story/2 called
      actions:
        - Call LLM with "decompose-specification.lua"
        - Extract specification from response
        - Pass to pseudocode phase

    - name: pseudocode_phase
      from: specification_generated
      to: pseudocode_generated
      trigger: Specification succeeded
      actions:
        - Call LLM with "decompose-pseudocode.lua"
        - Extract pseudocode from response
        - Pass to architecture phase

    - name: architecture_phase
      from: pseudocode_generated
      to: architecture_generated
      trigger: Pseudocode succeeded
      actions:
        - Call LLM with "decompose-architecture.lua"
        - Extract architecture from response
        - Pass to refinement phase

    - name: refinement_phase
      from: architecture_generated
      to: refinement_generated
      trigger: Architecture succeeded
      actions:
        - Call LLM with "decompose-refinement.lua"
        - Extract refinement from response
        - Pass to completion phase

    - name: completion_phase
      from: refinement_generated
      to: tasks_generated
      trigger: Refinement succeeded
      actions:
        - Call LLM with "decompose-tasks.lua"
        - Extract tasks from response
        - Return complete decomposition map

    - name: cascade_failure
      from: any
      to: error
      trigger: Any LLM call fails
      actions:
        - Log error with phase context
        - Return error tuple
        - Abort remaining phases

  depends_on:
    - Singularity.LLM.Service (MUST be available)
    - templates_data/prompt_library/sparc/*.lua (MUST exist)
    - complexity level support (simple/medium/complex)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create StoryBreakdown, UserStoryDecomposer, or SPARCOrchestrator duplicates
  **Why:** StoryDecomposer is the canonical SPARC 5-phase decomposer; all story breakdown should use it.

  ```elixir
  # ❌ WRONG - Duplicate story decomposer
  defmodule MyApp.StoryBreakdown do
    def break_down_story(story) do
      # Re-implementing SPARC phases
    end
  end

  # ✅ CORRECT - Use StoryDecomposer
  {:ok, decomposition} = StoryDecomposer.decompose_story(story)
  ```

  #### ❌ DO NOT skip SPARC phases or call them out of order
  **Why:** SPARC phases build on each other; skipping or reordering breaks design integrity.

  ```elixir
  # ❌ WRONG - Skip architecture phase
  {:ok, spec} = generate_specification(story)
  {:ok, tasks} = generate_tasks(spec)  # Missing architecture!

  # ✅ CORRECT - Follow SPARC sequence
  {:ok, decomposition} = StoryDecomposer.decompose_story(story)
  # => All 5 phases executed in order
  ```

  #### ❌ DO NOT call LLM.Service directly for SPARC phases
  **Why:** StoryDecomposer manages script selection, error handling, and phase sequencing.

  ```elixir
  # ❌ WRONG - Direct LLM call bypasses SPARC structure
  {:ok, result} = LLM.Service.call(:complex, "generate spec", ...)

  # ✅ CORRECT - Use StoryDecomposer for structured decomposition
  {:ok, decomposition} = StoryDecomposer.decompose_story(story)
  ```

  #### ❌ DO NOT apply generated tasks without reviewing refinement
  **Why:** Refinement phase optimizes design and handles edge cases; skipping it risks poor implementation.

  ```elixir
  # ❌ WRONG - Use tasks without refinement review
  decomposition = StoryDecomposer.decompose_story(story)
  tasks = decomposition.tasks
  execute_tasks(tasks)  # Unrefined!

  # ✅ CORRECT - Review refinement before task execution
  decomposition = StoryDecomposer.decompose_story(story)
  refinement = decomposition.refinement
  # Review refinement suggestions, then execute tasks
  execute_tasks(decomposition.tasks)
  ```

  ### Search Keywords

  SPARC framework, story decomposition, user story breakdown, specification generation,
  pseudocode generation, architecture design, refinement cycle, task generation,
  systematic design, Lua scripting, LLM-driven planning, acceptance criteria,
  implementation planning, design methodology, phase-based decomposition
  """

  require Logger

  # INTEGRATION: LLM operations (NATS-based story analysis)
  alias Singularity.LLM.Service

  @doc "Decompose a user story using SPARC methodology"
  def decompose_story(story, opts \\ []) do
    with {:ok, specification} <- generate_specification(story, opts),
         {:ok, pseudocode} <- generate_pseudocode(specification, opts),
         {:ok, architecture} <- design_architecture(pseudocode, opts),
         {:ok, refinement} <- refine_design(architecture, opts),
         {:ok, tasks} <- generate_completion_tasks(refinement, opts) do
      {:ok,
       %{
         specification: specification,
         pseudocode: pseudocode,
         architecture: architecture,
         refinement: refinement,
         tasks: tasks
       }}
    end
  end

  ## SPARC Phases

  # S - Specification
  defp generate_specification(story, opts) do
    # Extract options with defaults
    complexity = Keyword.get(opts, :complexity, :medium)
    language = Keyword.get(opts, :language, "any")

    # Use Lua script for SPARC specification phase
    case Service.call_with_script(
           "sparc/decompose-specification.lua",
           %{story: story, language: language},
           complexity: complexity,
           task_type: :planning
         ) do
      {:ok, %{text: text}} ->
        {:ok, text}

      {:error, reason} ->
        Logger.error("SPARC specification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # P - Pseudocode
  defp generate_pseudocode(spec, opts) do
    complexity = Keyword.get(opts, :complexity, :medium)

    case Service.call_with_script(
           "sparc/decompose-pseudocode.lua",
           %{specification: spec},
           complexity: complexity,
           task_type: :planning
         ) do
      {:ok, %{text: text}} -> {:ok, text}
      {:error, reason} -> {:error, reason}
    end
  end

  # A - Architecture
  defp design_architecture(pseudocode, opts) do
    complexity = Keyword.get(opts, :complexity, :medium)

    case Service.call_with_script(
           "sparc/decompose-architecture.lua",
           %{pseudocode: pseudocode},
           complexity: complexity,
           task_type: :architect
         ) do
      {:ok, %{text: text}} -> {:ok, text}
      {:error, reason} -> {:error, reason}
    end
  end

  # R - Refinement
  defp refine_design(architecture, opts) do
    complexity = Keyword.get(opts, :complexity, :medium)

    case Service.call_with_script(
           "sparc/decompose-refinement.lua",
           %{architecture: architecture},
           complexity: complexity,
           task_type: :architect
         ) do
      {:ok, %{text: text}} -> {:ok, text}
      {:error, reason} -> {:error, reason}
    end
  end

  # C - Completion Tasks
  defp generate_completion_tasks(refinement, opts) do
    complexity = Keyword.get(opts, :complexity, :medium)

    case Service.call_with_script(
           "sparc/decompose-tasks.lua",
           %{refinement: refinement},
           complexity: complexity,
           task_type: :planning
         ) do
      {:ok, %{text: text}} -> {:ok, text}
      {:error, reason} -> {:error, reason}
    end
  end

  # NOTE: All SPARC prompts moved to Lua scripts in templates_data/prompt_library/sparc/
  # - decompose-specification.lua
  # - decompose-pseudocode.lua
  # - decompose-architecture.lua
  # - decompose-refinement.lua
  # - decompose-tasks.lua

  # TODO: Ensure the story decomposition process integrates with the SPARC completion phase for final code generation.
  # TODO: Add metrics to evaluate the effectiveness of story decomposition in producing actionable tasks.
end
