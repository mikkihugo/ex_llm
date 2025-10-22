defmodule Singularity.GeneratorEngine.Pseudocode do
  @moduledoc """
  Pseudocode Generation Engine.

  Generates pseudocode structures from natural language descriptions using LLM capabilities.
  """

  require Logger
  alias Singularity.LLM.Service
  alias Singularity.Util

  @doc """
  Generate pseudocode from a natural language description.

  Uses LLM to intelligently extract algorithmic steps and parameters.
  """
  @spec generate_pseudocode(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def generate_pseudocode(description, language) do
    system_prompt = """
    You are an expert software engineer specializing in algorithm design and pseudocode generation.

    Your task is to analyze a natural language description and generate structured pseudocode with:
    1. Clear algorithmic steps
    2. Input/output parameters
    3. Control flow structures
    4. Data structures used

    Format your response as JSON with this structure:
    {
      "steps": ["step 1", "step 2", "step 3"],
      "parameters": {
        "inputs": ["param1", "param2"],
        "outputs": ["result"]
      },
      "data_structures": ["array", "hash_map"],
      "complexity": "O(n)" | "O(n^2)" | "O(log n)" | etc.
    }

    Focus on clarity and algorithmic correctness. Use standard pseudocode conventions.
    """

    user_prompt = """
    Generate pseudocode for: #{description}

    Target language: #{language}

    Provide a complete algorithmic breakdown with steps, parameters, and complexity analysis.
    """

    case Service.call_with_system(:complex, system_prompt, user_prompt) do
      {:ok, %{text: response_text}} ->
        case Jason.decode(response_text) do
          {:ok, parsed} ->
            {:ok, %{
              name: Util.slug(description),
              description: description,
              language: language,
              steps: parsed["steps"] || [],
              parameters: parsed["parameters"] || %{"inputs" => [], "outputs" => []},
              data_structures: parsed["data_structures"] || [],
              complexity: parsed["complexity"] || "unknown",
              generated_at: DateTime.utc_now()
            }}
          {:error, decode_error} ->
            Logger.warning("Failed to parse LLM response as JSON: #{inspect(decode_error)}")
            # Fallback to simple extraction
            {:ok, generate_fallback_pseudocode(description, language)}
        end
      {:error, error} ->
        Logger.error("LLM call failed: #{inspect(error)}")
        # Fallback to simple extraction
        {:ok, generate_fallback_pseudocode(description, language)}
    end
  end

  @doc """
  Generate function-level pseudocode.

  Creates pseudocode for a single function with parameters and return values.
  """
  @spec generate_function_pseudocode(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def generate_function_pseudocode(description, language) do
    system_prompt = """
    You are an expert software engineer specializing in function design and pseudocode.

    Generate pseudocode for a function that implements the described behavior.
    Include:
    1. Function signature with parameters
    2. Step-by-step algorithm
    3. Return value specification
    4. Error handling if applicable

    Format as JSON:
    {
      "function_name": "descriptive_name",
      "parameters": ["param1: type", "param2: type"],
      "return_type": "return_type",
      "steps": ["step 1", "step 2"],
      "error_cases": ["error condition"]
    }
    """

    user_prompt = """
    Create a function pseudocode for: #{description}

    Language: #{language}

    Make it production-ready with proper error handling.
    """

    case Service.call_with_system(:medium, system_prompt, user_prompt) do
      {:ok, %{text: response_text}} ->
        case Jason.decode(response_text) do
          {:ok, parsed} ->
            {:ok, %{
              type: "function",
              name: parsed["function_name"] || Util.slug(description),
              description: description,
              language: language,
              parameters: parsed["parameters"] || [],
              return_type: parsed["return_type"] || "void",
              steps: parsed["steps"] || [],
              error_cases: parsed["error_cases"] || [],
              generated_at: DateTime.utc_now()
            }}
          {:error, _} ->
            {:ok, generate_fallback_function_pseudocode(description, language)}
        end
      {:error, _} ->
        {:ok, generate_fallback_function_pseudocode(description, language)}
    end
  end

  @doc """
  Generate module-level pseudocode.

  Creates pseudocode for a module/class with multiple functions.
  """
  @spec generate_module_pseudocode(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def generate_module_pseudocode(description, language) do
    system_prompt = """
    You are an expert software architect specializing in module design.

    Design a software module that implements the described functionality.
    Include:
    1. Module name and purpose
    2. Public interface (functions/methods)
    3. Internal structure
    4. Dependencies

    Format as JSON:
    {
      "module_name": "ModuleName",
      "purpose": "module purpose",
      "public_functions": [
        {
          "name": "function_name",
          "parameters": ["param1"],
          "description": "what it does"
        }
      ],
      "private_functions": ["helper1", "helper2"],
      "data_structures": ["struct1", "struct2"],
      "dependencies": ["dep1", "dep2"]
    }
    """

    user_prompt = """
    Design a software module for: #{description}

    Language: #{language}

    Focus on clean architecture and separation of concerns.
    """

    case Service.call_with_system(:complex, system_prompt, user_prompt) do
      {:ok, %{text: response_text}} ->
        case Jason.decode(response_text) do
          {:ok, parsed} ->
            {:ok, %{
              type: "module",
              name: parsed["module_name"] || Util.slug(description),
              description: description,
              language: language,
              purpose: parsed["purpose"] || description,
              public_functions: parsed["public_functions"] || [],
              private_functions: parsed["private_functions"] || [],
              data_structures: parsed["data_structures"] || [],
              dependencies: parsed["dependencies"] || [],
              generated_at: DateTime.utc_now()
            }}
          {:error, _} ->
            {:ok, generate_fallback_module_pseudocode(description, language)}
        end
      {:error, _} ->
        {:ok, generate_fallback_module_pseudocode(description, language)}
    end
  end

  @doc """
  Generate project structure pseudocode.

  Creates high-level pseudocode for an entire project architecture.
  """
  @spec generate_project_structure(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def generate_project_structure(description, language) do
    system_prompt = """
    You are a software architect specializing in system design and project structure.

    Design a complete software project that implements the described system.
    Include:
    1. Overall architecture
    2. Module breakdown
    3. Data flow
    4. Key components

    Format as JSON:
    {
      "project_name": "ProjectName",
      "architecture": "architecture_type",
      "modules": [
        {
          "name": "module_name",
          "responsibility": "what it does",
          "dependencies": ["dep1"]
        }
      ],
      "data_flow": ["step1 -> step2 -> step3"],
      "technologies": ["tech1", "tech2"],
      "entry_points": ["main_function"]
    }
    """

    user_prompt = """
    Design a complete software project for: #{description}

    Primary language: #{language}

    Consider scalability, maintainability, and best practices.
    """

    case Service.call_with_system(:complex, system_prompt, user_prompt) do
      {:ok, %{text: response_text}} ->
        case Jason.decode(response_text) do
          {:ok, parsed} ->
            {:ok, %{
              type: "project",
              name: parsed["project_name"] || Util.slug(description),
              description: description,
              language: language,
              architecture: parsed["architecture"] || "modular",
              modules: parsed["modules"] || [],
              data_flow: parsed["data_flow"] || [],
              technologies: parsed["technologies"] || [language],
              entry_points: parsed["entry_points"] || [],
              generated_at: DateTime.utc_now()
            }}
          {:error, _} ->
            {:ok, generate_fallback_project_structure(description, language)}
        end
      {:error, _} ->
        {:ok, generate_fallback_project_structure(description, language)}
    end
  end

  # Fallback implementations for when LLM is unavailable

  defp generate_fallback_pseudocode(description, language) do
    %{
      name: Util.slug(description),
      description: description,
      language: language,
      steps: extract_steps(description),
      parameters: extract_parameters(description),
      data_structures: [],
      complexity: "unknown",
      generated_at: DateTime.utc_now()
    }
  end

  defp generate_fallback_function_pseudocode(description, language) do
    %{
      type: "function",
      name: Util.slug(description),
      description: description,
      language: language,
      parameters: extract_parameters(description)["inputs"] || [],
      return_type: "result",
      steps: extract_steps(description),
      error_cases: [],
      generated_at: DateTime.utc_now()
    }
  end

  defp generate_fallback_module_pseudocode(description, language) do
    %{
      type: "module",
      name: Util.slug(description),
      description: description,
      language: language,
      purpose: description,
      public_functions: [%{"name" => "process", "parameters" => [], "description" => description}],
      private_functions: [],
      data_structures: [],
      dependencies: [],
      generated_at: DateTime.utc_now()
    }
  end

  defp generate_fallback_project_structure(description, language) do
    %{
      type: "project",
      name: Util.slug(description),
      description: description,
      language: language,
      architecture: "modular",
      modules: [%{"name" => "core", "responsibility" => description, "dependencies" => []}],
      data_flow: ["input -> process -> output"],
      technologies: [language],
      entry_points: ["main"],
      generated_at: DateTime.utc_now()
    }
  end

  # Simple extraction functions (used as fallbacks)

  defp extract_steps(description) do
    # Split by common connectors and clean up
    connectors = ~r/\s+(?:then|next|after|finally|and|or|but|so)\s+/i

    description
    |> String.split(connectors)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(10) # Limit to reasonable number
  end

  defp extract_parameters(description) do
    # Simple regex patterns for common parameters
    input_patterns = [
      ~r/\b(input|data|value|number|string|list|array)\b/i,
      ~r/\b(file|path|url|address)\b/i,
      ~r/\b(user|name|id|key)\b/i
    ]

    output_patterns = [
      ~r/\b(result|output|return|answer)\b/i,
      ~r/\b(list|array|map|object)\b/i,
      ~r/\b(status|code|message)\b/i
    ]

    inputs = Enum.flat_map(input_patterns, &Regex.scan(&1, description))
             |> List.flatten()
             |> Enum.uniq()

    outputs = Enum.flat_map(output_patterns, &Regex.scan(&1, description))
              |> List.flatten()
              |> Enum.uniq()

    %{"inputs" => inputs, "outputs" => outputs}
  end
end
