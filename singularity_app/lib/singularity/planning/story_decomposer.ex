defmodule Singularity.Planning.StoryDecomposer do
  @moduledoc """
  SPARC framework story decomposer for systematic user story breakdown and task generation.

  Implements the SPARC methodology (Specification, Pseudocode, Architecture, Refinement, Completion)
  to decompose user stories into detailed technical specifications, implementation plans,
  and actionable tasks with fallback mechanisms for LLM reliability.

  ## Integration Points

  This module integrates with:
  - `Singularity.LLM.Service` - LLM operations (Service.call/3 for story analysis)
  - PostgreSQL table: `story_decompositions` (stores decomposition results)

  ## SPARC Phases

  - **Specification** - Generate detailed technical requirements
  - **Pseudocode** - Create implementation algorithm logic
  - **Architecture** - Design system modules and data flow
  - **Refinement** - Review and optimize design
  - **Completion** - Generate actionable implementation tasks

  ## Usage

      # Decompose a user story
      {:ok, decomposition} = StoryDecomposer.decompose_story(%{
        description: "As a user, I want to authenticate with OAuth2",
        acceptance_criteria: ["User can login with Google", "Session is maintained"]
      })
      # => {:ok, %{specification: %{...}, pseudocode: "...", architecture: %{...}, tasks: [...]}}
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
    # Use Lua script for SPARC specification phase
    case Service.call_with_script(
      "sparc/decompose-specification.lua",
      %{story: story},
      complexity: :medium,
      task_type: :planning
    ) do
      {:ok, %{text: text}} -> {:ok, text}
      {:error, reason} ->
        Logger.error("SPARC specification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # P - Pseudocode
  defp generate_pseudocode(spec, _opts) do
    case Service.call_with_script(
      "sparc/decompose-pseudocode.lua",
      %{specification: spec},
      complexity: :medium,
      task_type: :planning
    ) do
      {:ok, %{text: text}} -> {:ok, text}
      {:error, reason} -> {:error, reason}
    end
  end

  # A - Architecture
  defp design_architecture(pseudocode, _opts) do
    case Service.call_with_script(
      "sparc/decompose-architecture.lua",
      %{pseudocode: pseudocode},
      complexity: :medium,
      task_type: :architect
    ) do
      {:ok, %{text: text}} -> {:ok, text}
      {:error, reason} -> {:error, reason}
    end
  end

  # R - Refinement
  defp refine_design(architecture, _opts) do
    case Service.call_with_script(
      "sparc/decompose-refinement.lua",
      %{architecture: architecture},
      complexity: :medium,
      task_type: :architect
    ) do
      {:ok, %{text: text}} -> {:ok, text}
      {:error, reason} -> {:error, reason}
    end
  end

  # C - Completion Tasks
  defp generate_completion_tasks(refinement, _opts) do
    case Service.call_with_script(
      "sparc/decompose-tasks.lua",
      %{refinement: refinement},
      complexity: :medium,
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
