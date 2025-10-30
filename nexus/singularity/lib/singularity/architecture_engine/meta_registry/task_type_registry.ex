defmodule Singularity.MetaRegistry.TaskTypeRegistry do
  @moduledoc """
  Task type registry for managing LLM task types and their complexity mappings.

  This registry centralizes task type definitions and their associated complexity levels,
  making task types configurable and discoverable throughout the system.

  ## Task Types by Complexity

  ### Complex Tasks (:complex)
  - `:architect` - System architecture design and analysis
  - `:code_generation` - Generating new code from specifications
  - `:pattern_analyzer` - Complex pattern recognition and analysis
  - `:refactoring` - Code restructuring and optimization
  - `:code_analysis` - Deep code understanding and analysis
  - `:qa` - Quality assurance and testing strategy

  ### Medium Tasks (:medium)
  - `:coder` - General programming and implementation
  - `:decomposition` - Breaking down complex problems
  - `:planning` - Task and project planning
  - `:pseudocode` - Algorithm design and pseudocode generation
  - `:chat` - Interactive conversational AI

  ### Simple Tasks (:simple)
  - `:classifier` - Classification and categorization tasks
  - `:parser` - Data parsing and extraction
  - `:simple_chat` - Basic conversational responses
  - `:web_search` - Information retrieval and search
  """

  @task_types %{
    # Complex tasks - require premium models (Claude Opus, GPT-4)
    architect: %{complexity: :complex, description: "System architecture design and analysis"},
    code_generation: %{
      complexity: :complex,
      description: "Generating new code from specifications"
    },
    pattern_analyzer: %{
      complexity: :complex,
      description: "Complex pattern recognition and analysis"
    },
    refactoring: %{complexity: :complex, description: "Code restructuring and optimization"},
    code_analysis: %{complexity: :complex, description: "Deep code understanding and analysis"},
    qa: %{complexity: :complex, description: "Quality assurance and testing strategy"},

    # Medium tasks - balanced models (Claude Sonnet)
    coder: %{complexity: :medium, description: "General programming and implementation"},
    decomposition: %{complexity: :medium, description: "Breaking down complex problems"},
    planning: %{complexity: :medium, description: "Task and project planning"},
    pseudocode: %{complexity: :medium, description: "Algorithm design and pseudocode generation"},
    chat: %{complexity: :medium, description: "Interactive conversational AI"},

    # Simple tasks - fast models (Gemini Flash)
    classifier: %{complexity: :simple, description: "Classification and categorization tasks"},
    parser: %{complexity: :simple, description: "Data parsing and extraction"},
    simple_chat: %{complexity: :simple, description: "Basic conversational responses"},
    web_search: %{complexity: :simple, description: "Information retrieval and search"}
  }

  @doc """
  Get the complexity level for a task type.

  ## Examples

      iex> get_complexity(:architect)
      :complex

      iex> get_complexity(:classifier)
      :simple

      iex> get_complexity(:unknown_task)
      nil
  """
  @spec get_complexity(atom()) :: :simple | :medium | :complex | nil
  def get_complexity(task_type) do
    case Map.get(@task_types, task_type) do
      %{complexity: complexity} -> complexity
      nil -> nil
    end
  end

  @doc """
  Get the full metadata for a task type.

  ## Examples

      iex> get_task_info(:architect)
      %{complexity: :complex, description: "System architecture design and analysis"}

      iex> get_task_info(:unknown_task)
      nil
  """
  @spec get_task_info(atom()) :: %{complexity: atom(), description: String.t()} | nil
  def get_task_info(task_type) do
    Map.get(@task_types, task_type)
  end

  @doc """
  Get all task types for a given complexity level.

  ## Examples

      iex> get_tasks_by_complexity(:complex)
      [:architect, :code_generation, :pattern_analyzer, :refactoring, :code_analysis, :qa]

      iex> get_tasks_by_complexity(:simple)
      [:classifier, :parser, :simple_chat, :web_search]
  """
  @spec get_tasks_by_complexity(:simple | :medium | :complex) :: [atom()]
  def get_tasks_by_complexity(complexity) do
    @task_types
    |> Enum.filter(fn {_task, %{complexity: task_complexity}} ->
      task_complexity == complexity
    end)
    |> Enum.map(fn {task, _info} -> task end)
    |> Enum.sort()
  end

  @doc """
  Get all registered task types.

  ## Examples

      iex> get_all_task_types()
      [:architect, :chat, :classifier, :code_analysis, :code_generation,
       :coder, :decomposition, :parser, :pattern_analyzer, :planning,
       :pseudocode, :qa, :refactoring, :simple_chat, :web_search]
  """
  @spec get_all_task_types() :: [atom()]
  def get_all_task_types do
    @task_types
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  Check if a task type is registered.

  ## Examples

      iex> task_registered?(:architect)
      true

      iex> task_registered?(:unknown_task)
      false
  """
  @spec task_registered?(atom()) :: boolean()
  def task_registered?(task_type) do
    Map.has_key?(@task_types, task_type)
  end

  @doc """
  Get task types grouped by complexity level.

  ## Examples

      iex> get_task_types_by_complexity()
      %{
        complex: [:architect, :code_analysis, :code_generation, :pattern_analyzer, :qa, :refactoring],
        medium: [:chat, :coder, :decomposition, :planning, :pseudocode],
        simple: [:classifier, :parser, :simple_chat, :web_search]
      }
  """
  @spec get_task_types_by_complexity() :: %{
          complex: [atom()],
          medium: [atom()],
          simple: [atom()]
        }
  def get_task_types_by_complexity do
    %{
      complex: get_tasks_by_complexity(:complex),
      medium: get_tasks_by_complexity(:medium),
      simple: get_tasks_by_complexity(:simple)
    }
  end
end
