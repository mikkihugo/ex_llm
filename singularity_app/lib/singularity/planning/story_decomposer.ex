defmodule Singularity.Planning.StoryDecomposer do
  @moduledoc """
  SPARC framework by ruvnet for story decomposition:
  - Specification
  - Pseudocode
  - Architecture
  - Refinement
  - Completion
  """

  require Logger

  alias Singularity.Integration.Claude

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
    prompt = """
    Act as a technical specification writer.

    User Story: #{story.description}
    Acceptance Criteria: #{Enum.join(story.acceptance_criteria || [], "\n")}

    Generate a detailed technical specification with:
    1. Functional requirements
    2. Non-functional requirements
    3. Data models
    4. API contracts (if applicable)
    5. Edge cases
    6. Error handling

    Return JSON:
    {
      "functional_requirements": ["req1", "req2"],
      "nfrs": ["nfr1", "nfr2"],
      "data_models": ["model1 description"],
      "api_contracts": ["endpoint1 spec"],
      "edge_cases": ["case1"],
      "error_handling": ["strategy1"]
    }
    """

    call_llm(prompt, opts)
  end

  # P - Pseudocode
  defp generate_pseudocode(spec, opts) do
    prompt = """
    Act as a senior developer creating implementation pseudocode.

    Specification:
    #{inspect(spec, pretty: true)}

    Create detailed pseudocode covering:
    1. Core algorithm logic
    2. Data transformations
    3. Control flow
    4. Error paths
    5. Integration points

    Return plain text pseudocode.
    """

    call_llm(prompt, opts)
  end

  # A - Architecture
  defp design_architecture(pseudocode, opts) do
    prompt = """
    Act as a solutions architect.

    Pseudocode:
    #{inspect(pseudocode, pretty: true)}

    Design the technical architecture as JSON:
    {
      "modules": [
        {
          "name": "ModuleName",
          "purpose": "...",
          "dependencies": ["dep1"]
        }
      ],
      "data_flow": "description",
      "integration_patterns": ["pattern1"],
      "scalability": "considerations",
      "security": "boundaries"
    }
    """

    call_llm(prompt, opts)
  end

  # R - Refinement
  defp refine_design(architecture, opts) do
    prompt = """
    Act as a code reviewer providing design refinement.

    Architecture:
    #{inspect(architecture, pretty: true)}

    Review and refine as JSON:
    {
      "bottlenecks": ["bottleneck1"],
      "optimizations": ["opt1"],
      "test_strategies": ["strategy1"],
      "error_handling_improvements": ["improvement1"],
      "observability_enhancements": ["enhancement1"]
    }
    """

    call_llm(prompt, opts)
  end

  # C - Completion Tasks
  defp generate_completion_tasks(refinement, opts) do
    prompt = """
    Act as a technical lead breaking down implementation work.

    Refined Design:
    #{inspect(refinement, pretty: true)}

    Generate implementation tasks as JSON array:
    [
      {
        "id": "task-1",
        "title": "...",
        "description": "...",
        "type": "code|test|doc|deploy",
        "estimated_hours": 4,
        "dependencies": [],
        "acceptance": "...",
        "code_files": ["path/to/file.ex"]
      }
    ]
    """

    call_llm(prompt, opts)
  end

  ## Helpers

  defp call_llm(prompt, opts) do
    provider = Keyword.get(opts, :provider, :claude)

    case provider do
      :claude -> Claude.chat(prompt, opts)
      _ -> {:error, :unsupported_provider}
    end
  end
end
