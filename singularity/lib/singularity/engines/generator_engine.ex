defmodule Singularity.GeneratorEngine do
  @moduledoc """
  Generator Engine - AI-powered code generation with intelligent naming

  Provides unified code generation capabilities using the Rust generator_engine NIF.
  This is the ONLY code generator interface - all other generators should use this.

  ## Features:
  - Generate clean code from pseudocode
  - Intelligent naming and validation
  - Microservice and monorepo structure suggestions
  - Language-specific code generation
  - Pseudocode generation and conversion

  ## Usage:

      # Generate clean code
      {:ok, code} = GeneratorEngine.generate_clean_code(description, language)
      
      # Generate pseudocode
      {:ok, pseudocode} = GeneratorEngine.generate_pseudocode(description, language)
      
      # Suggest microservice structure
      {:ok, structure} = GeneratorEngine.suggest_microservice_structure("user-service", "elixir")
  """

  alias Singularity.CodeGeneration.Implementations.GeneratorEngine.{
    Code,
    Naming,
    Pseudocode,
    Structure
  }

  @behaviour Singularity.Engine

  @impl Singularity.Engine
  def id, do: :generator

  @impl Singularity.Engine
  def label, do: "Generator Engine"

  @impl Singularity.Engine
  def description,
    do: "AI-assisted code and pseudocode generation with architecture-aware naming support."

  @impl Singularity.Engine
  def capabilities do
    [
      %{
        id: :code_generation,
        label: "Code Generation",
        description: "Transform natural language intents into language-specific code snippets.",
        available?: true,
        tags: [:generation, :ai, :nif_fallback]
      },
      %{
        id: :pseudocode,
        label: "Pseudocode Planning",
        description: "Produce structured pseudocode plans to guide downstream generation.",
        available?: true,
        tags: [:planning, :generation]
      },
      %{
        id: :architecture_structures,
        label: "Architecture Structures",
        description: "Suggest microservice and monorepo scaffolding for new projects.",
        available?: true,
        tags: [:architecture, :scaffolding]
      },
      %{
        id: :naming_validation,
        label: "Naming Validation",
        description: "Validate identifiers against language-specific conventions.",
        available?: true,
        tags: [:naming, :lint]
      }
    ]
  end

  @impl Singularity.Engine
  def health, do: :ok

  # ============================================================================
  # NIF FUNCTIONS (Fast Local)
  # ============================================================================

  @doc """
  Generate clean code from description and language

  ## Examples

      iex> GeneratorEngine.generate_clean_code("async worker with error handling", "elixir")
      {:ok, "defmodule Worker do\n  use GenServer\n  \n  def start_link(_opts) do\n    GenServer.start_link(__MODULE__, _opts, name: __MODULE__)\n  end\nend"}
  """
  def generate_clean_code(description, language),
    do: Code.generate_clean_code(description, language)

  @doc """
  Generate pseudocode from description and language

  ## Examples

      iex> GeneratorEngine.generate_pseudocode("user authentication", "elixir")
      {:ok, %{
        functions: [%{name: "authenticate_user", params: ["email", "password"]}],
        modules: [%{name: "UserAuth", purpose: "Handle user authentication"}]
      }}
  """
  def generate_pseudocode(description, language),
    do: Pseudocode.generate_pseudocode(description, language)

  @doc """
  Convert pseudocode to clean code

  ## Examples

      iex> GeneratorEngine.convert_to_clean_code(pseudocode, "elixir")
      {:ok, "defmodule UserAuth do\n  def authenticate_user(email, password) do\n    # Implementation\n  end\nend"}
  """
  def convert_to_clean_code(pseudocode, language),
    do: Code.convert_to_clean_code(pseudocode, language)

  @doc """
  Suggest microservice structure for domain and language

  ## Examples

      iex> GeneratorEngine.suggest_microservice_structure("user-service", "elixir")
      {:ok, %{
        structure: %{
          modules: ["UserService", "UserController", "UserRepository"],
          files: ["lib/user_service.ex", "lib/user_controller.ex"],
          directories: ["lib/", "test/", "config/"]
        }
      }}
  """
  def suggest_microservice_structure(domain, language),
    do: Structure.suggest_microservice_structure(domain, language)

  @doc """
  Suggest monorepo structure for build system and project type

  ## Examples

      iex> GeneratorEngine.suggest_monorepo_structure("mix", "elixir")
      {:ok, %{
        structure: %{
          apps: ["user_service", "payment_service"],
          shared: ["lib/shared/", "test/shared/"],
          root_files: ["mix.exs", "README.md"]
        }
      }}
  """
  def suggest_monorepo_structure(build_system, project_type),
    do: Structure.suggest_monorepo_structure(build_system, project_type)

  @doc """
  Validate naming compliance for name and element type

  ## Examples

      iex> GeneratorEngine.validate_naming_compliance("user_service", :module)
      true
      
      iex> GeneratorEngine.validate_naming_compliance("UserService", :module)
      false
  """
  def validate_naming_compliance(name, element_type),
    do: Naming.validate_naming_compliance(name, element_type)

  @doc """
  Search existing names by query and filters

  ## Examples

      iex> GeneratorEngine.search_existing_names("user", :business_logic, :module)
      {:ok, [%{name: "user_service", description: "Handles user operations"}]}
  """
  def search_existing_names(query, category, element_type),
    do: Naming.search_existing_names(query, category, element_type)

  @doc """
  Get name description for a given name

  ## Examples

      iex> GeneratorEngine.get_name_description("user_service")
      {:ok, "Handles user-related operations and business logic"}
  """
  def get_name_description(name), do: Naming.get_name_description(name)

  @doc """
  List all names with optional category filter

  ## Examples

      iex> GeneratorEngine.list_all_names(:business_logic)
      {:ok, [{"user_service", "User operations"}, {"payment_service", "Payment processing"}]}
  """
  def list_all_names(category), do: Naming.list_all_names(category)

  @doc """
  Get language-specific description for name and language

  ## Examples

      iex> GeneratorEngine.get_language_specific_description("user_service", "elixir", file_content)
      {:ok, "Elixir module for user service operations"}
  """
  def get_language_specific_description(name, language, file_content),
    do: Naming.get_language_specific_description(name, language, file_content)

  # ============================================================================
  # CONVENIENCE FUNCTIONS (Elixir Layer)
  # ============================================================================

  @doc """
  Generate function pseudocode

  ## Examples

      iex> GeneratorEngine.generate_function_pseudocode("authenticate user", "elixir")
      {:ok, %{
        name: "authenticate_user",
        params: ["email", "password"],
        return_type: "boolean",
        steps: ["validate email format", "check password hash", "return result"]
      }}
  """
  def generate_function_pseudocode(description, language),
    do: Pseudocode.generate_function_pseudocode(description, language)

  @doc """
  Generate module pseudocode

  ## Examples

      iex> GeneratorEngine.generate_module_pseudocode("user service", "elixir")
      {:ok, %{
        name: "UserService",
        purpose: "Handle user operations",
        functions: ["create_user", "update_user", "delete_user"]
      }}
  """
  def generate_module_pseudocode(description, language),
    do: Pseudocode.generate_module_pseudocode(description, language)

  @doc """
  Generate complete project structure

  ## Examples

      iex> GeneratorEngine.generate_project_structure("user management system", "elixir")
      {:ok, %{
        structure: %{
          modules: ["UserService", "UserController", "UserRepository"],
          files: ["lib/user_service.ex", "lib/user_controller.ex", "lib/user_repository.ex"],
          directories: ["lib/", "test/", "config/", "priv/"]
        }
      }}
  """
  def generate_project_structure(description, language),
    do: Pseudocode.generate_project_structure(description, language)

  @doc """
  Validate and suggest improvements for code

  ## Examples

      iex> GeneratorEngine.validate_and_improve("def UserService do\nend", "elixir")
      {:ok, %{
        valid: false,
        suggestions: ["Use 'defmodule' instead of 'def'", "Add proper module structure"],
        improved_code: "defmodule UserService do\n  # Add your functions here\nend"
      }}
  """
  def validate_and_improve(code, language),
    do: Code.validate_and_improve(code, language)

  # ============================================================================
  # CONSOLIDATED CODE GENERATION FUNCTIONS
  # ============================================================================

  @doc """
  Generate production-quality code using SPARC methodology + RAG.

  ## Parameters:
  - `task` - What to generate (e.g., 'Create GenServer for caching with TTL')
  - `language` - Target language: 'elixir', 'rust', 'typescript', 'python' (default: 'elixir')
  - `repo` - Codebase to learn patterns from (optional)
  - `quality` - Quality level: 'production', 'prototype', 'quick' (default: 'production')
  - `include_tests` - Generate tests (default: true for production)
  """
  def code_generate(
        task,
        language \\ "elixir",
        repo \\ nil,
        quality \\ "production",
        include_tests \\ true
      ),
      do: Code.code_generate(task, language, repo, quality, include_tests)

  @doc """
  Quick code generation using RAG (pattern-based).

  ## Parameters:
  - `task` - What to generate
  - `language` - Target language (default: 'elixir')
  - `repos` - List of repos to search for examples
  - `top_k` - Number of example patterns to use (default: 5)
  """
  def code_generate_quick(task, language \\ "elixir", repos \\ nil, top_k \\ 5),
    do: Code.code_generate_quick(task, language, repos, top_k)

  @doc """
  Find similar code examples from codebases.

  ## Parameters:
  - `query` - What to search for (e.g., 'async worker pattern')
  - `language` - Filter by language (optional)
  - `repos` - Repos to search (default: all)
  - `limit` - Max results (default: 5)
  """
  def code_find_examples(query, language \\ nil, repos \\ nil, limit \\ 5),
    do: Code.code_find_examples(query, language, repos, limit)

  @doc """
  Validate code quality against standards.

  ## Parameters:
  - `code` - Code to validate
  - `language` - Code language
  - `quality_level` - Expected quality: 'production', 'prototype' (default: 'production')
  """
  def code_validate(code, language, quality_level \\ "production"),
    do: Code.code_validate(code, language, quality_level)

  @doc """
  Refine code based on validation feedback.

  ## Parameters:
  - `code` - Original code to refine
  - `validation_result` - Validation result from code_validate
  - `language` - Code language
  - `focus` - Focus area: 'docs', 'tests', 'error_handling', 'all' (default: 'all')
  """
  def code_refine(code, validation_result, language, focus \\ "all"),
    do: Code.code_refine(code, validation_result, language, focus)

  @doc """
  Iteratively improve code until quality threshold is met.

  ## Parameters:
  - `task` - What to generate
  - `language` - Target language (default: 'elixir')
  - `quality_threshold` - Minimum quality score (default: 0.85)
  - `max_iterations` - Max iterations to prevent infinite loops (default: 3)
  """
  def code_iterate(task, language \\ "elixir", quality_threshold \\ 0.85, max_iterations \\ 3),
    do: Code.code_iterate(task, language, quality_threshold, max_iterations)
end
