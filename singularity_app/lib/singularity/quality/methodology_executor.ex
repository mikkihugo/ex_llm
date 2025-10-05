defmodule Singularity.MethodologyExecutor do
  @moduledoc """
  Executes the 5-phase SPARC methodology for code generation.

  S.P.A.R.C:
  1. Specification - Define what to build
  2. Pseudocode - Logic in plain language
  3. Architecture - System structure
  4. Refinement - Optimize and improve
  5. Completion - Final implementation

  This wires SPARC templates to actual code generation!
  """

  require Logger
  alias Singularity.{TechnologyTemplateLoader, RAGCodeGenerator, QualityCodeGenerator}
  alias Singularity.LLM.Provider

  @sparc_phases [
    {:specification, "sparc-specification", "Define requirements and constraints"},
    {:pseudocode, "sparc-pseudocode", "Write logic in plain language"},
    {:architecture, "sparc-architecture", "Design system structure"},
    {:refinement, "sparc-refinement", "Optimize and improve design"},
    {:completion, "sparc-completion", "Generate final production code"}
  ]

  @doc """
  Execute full SPARC workflow for a task

  Returns the final generated code after all 5 phases
  """
  def execute(task, opts \\ []) do
    Logger.info("Starting SPARC execution for: #{task}")

    # Initialize context that flows through phases
    context = %{
      task: task,
      language: Keyword.get(opts, :language, "elixir"),
      repo: Keyword.get(opts, :repo),
      phases_completed: [],
      artifacts: %{}
    }

    # Execute each phase sequentially
    final_context = Enum.reduce(@sparc_phases, context, fn {phase_name, template_id, description}, ctx ->
      Logger.info("SPARC Phase: #{phase_name} - #{description}")
      execute_phase(phase_name, template_id, ctx)
    end)

    # Return the final code
    {:ok, final_context.artifacts.code}
  end

  defp execute_phase(:specification, template_id, context) do
    # Phase 1: Load template and generate specification
    template = TechnologyTemplateLoader.template(template_id)

    # Use RAG to find similar specifications
    {:ok, examples} = RAGCodeGenerator.find_best_examples(
      "specification for #{context.task}",
      context.language,
      [context.repo],
      3,
      true,
      false
    )

    # Generate specification
    prompt = build_phase_prompt(template, context, examples)
    {:ok, spec} = Provider.call(:claude, %{prompt: prompt})

    context
    |> Map.put(:phases_completed, [:specification | context.phases_completed])
    |> put_in([:artifacts, :specification], spec)
  end

  defp execute_phase(:pseudocode, template_id, context) do
    # Phase 2: Convert specification to pseudocode
    template = TechnologyTemplateLoader.template(template_id)

    prompt = """
    Based on this specification:
    #{context.artifacts.specification}

    Write clear pseudocode following the template structure:
    #{Jason.encode!(template, pretty: true)}
    """

    {:ok, pseudocode} = Provider.call(:claude, %{prompt: prompt})

    context
    |> Map.put(:phases_completed, [:pseudocode | context.phases_completed])
    |> put_in([:artifacts, :pseudocode], pseudocode)
  end

  defp execute_phase(:architecture, template_id, context) do
    # Phase 3: Design architecture from pseudocode
    template = TechnologyTemplateLoader.template(template_id)

    # Find architectural patterns in codebase
    {:ok, patterns} = RAGCodeGenerator.find_best_examples(
      "architecture patterns #{context.language}",
      context.language,
      [context.repo],
      5,
      true,
      false
    )

    prompt = """
    Design the architecture for:
    #{context.artifacts.pseudocode}

    Use these proven patterns from the codebase:
    #{format_examples(patterns)}
    """

    {:ok, architecture} = Provider.call(:claude, %{prompt: prompt})

    context
    |> Map.put(:phases_completed, [:architecture | context.phases_completed])
    |> put_in([:artifacts, :architecture], architecture)
  end

  defp execute_phase(:refinement, template_id, context) do
    # Phase 4: Refine and optimize
    template = TechnologyTemplateLoader.template(template_id)

    # Check quality standards
    quality_template = QualityCodeGenerator.get_template(context.language)

    prompt = """
    Refine this architecture for production:
    #{context.artifacts.architecture}

    Apply these quality standards:
    #{Jason.encode!(quality_template, pretty: true)}

    Optimize for:
    - Performance
    - Security
    - Maintainability
    - Testing
    """

    {:ok, refined} = Provider.call(:claude, %{prompt: prompt})

    context
    |> Map.put(:phases_completed, [:refinement | context.phases_completed])
    |> put_in([:artifacts, :refined_design], refined)
  end

  defp execute_phase(:completion, template_id, context) do
    # Phase 5: Generate final code
    template = TechnologyTemplateLoader.template(template_id)

    # Use RAG to ensure consistency with codebase
    {:ok, code} = RAGCodeGenerator.generate(
      task: context.task,
      language: context.language,
      repos: [context.repo],
      context: %{
        specification: context.artifacts.specification,
        pseudocode: context.artifacts.pseudocode,
        architecture: context.artifacts.architecture,
        refined_design: context.artifacts.refined_design
      }
    )

    context
    |> Map.put(:phases_completed, [:completion | context.phases_completed])
    |> put_in([:artifacts, :code], code)
  end

  defp build_phase_prompt(template, context, examples) do
    """
    SPARC Phase: #{template["name"]}
    Task: #{context.task}
    Language: #{context.language}

    Template Structure:
    #{Jason.encode!(template, pretty: true)}

    Similar Examples from Codebase:
    #{format_examples(examples)}

    Generate output following the template structure.
    """
  end

  defp format_examples(examples) do
    examples
    |> Enum.take(3)
    |> Enum.map(fn ex ->
      """
      From #{ex.repo}/#{ex.path}:
      ```#{ex.language}
      #{String.slice(ex.content, 0..300)}
      ```
      """
    end)
    |> Enum.join("\n")
  end

  @doc """
  Execute a single SPARC phase (for testing/debugging)
  """
  def execute_phase_only(phase, task, opts \\ []) do
    {phase_name, template_id, _desc} =
      Enum.find(@sparc_phases, fn {name, _, _} -> name == phase end)

    context = %{
      task: task,
      language: Keyword.get(opts, :language, "elixir"),
      repo: Keyword.get(opts, :repo),
      phases_completed: [],
      artifacts: opts[:artifacts] || %{}
    }

    result = execute_phase(phase_name, template_id, context)
    {:ok, result.artifacts}
  end
end