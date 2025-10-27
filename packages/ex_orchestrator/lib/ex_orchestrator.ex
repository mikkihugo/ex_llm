defmodule ExOrchestrator do
  @moduledoc """
  ExOrchestrator - Complete workflow orchestration for Elixir.

  A unified package providing PGMQ-based message queuing, HTDAG goal decomposition,
  workflow execution, and real-time notifications. Converts high-level goals into
  executable task graphs with automatic dependency resolution and parallel execution.

  ## Features

  - **Goal Decomposition**: Convert high-level goals into hierarchical task graphs
  - **Workflow Execution**: Execute workflows with dependency resolution and parallel processing
  - **Message Queuing**: PGMQ-based reliable message queuing with PostgreSQL
  - **Real-time Notifications**: PostgreSQL NOTIFY integration for event-driven execution
  - **Smart Optimization**: Machine learning-based workflow optimization and learning
  - **Flexible**: Works with custom decomposer functions (LLM, rules, etc.)
  - **Observable**: Real-time workflow event broadcasting and monitoring

  ## Quick Start

      # Define a decomposer function
      defmodule MyApp.GoalDecomposer do
        def decompose(goal) do
          tasks = [
            %{id: "task1", description: "Analyze requirements", depends_on: []},
            %{id: "task2", description: "Design architecture", depends_on: ["task1"]},
            %{id: "task3", description: "Implement solution", depends_on: ["task2"]}
          ]
          {:ok, tasks}
        end
      end

      # Define step functions
      step_functions = %{
        "task1" => &MyApp.Tasks.analyze_requirements/1,
        "task2" => &MyApp.Tasks.design_architecture/1,
        "task3" => &MyApp.Tasks.implement_solution/1
      }

      # Compose and execute workflow
      {:ok, result} = ExOrchestrator.WorkflowComposer.compose_from_goal(
        "Build user authentication system",
        &MyApp.GoalDecomposer.decompose/1,
        step_functions,
        MyApp.Repo
      )

  ## Architecture

  ExOrchestrator combines several key components:

  - **HTDAG**: Hierarchical Task Directed Acyclic Graph for goal decomposition
  - **PGMQ**: PostgreSQL-based message queuing for reliable workflow execution
  - **Notifications**: Real-time event broadcasting via PostgreSQL NOTIFY
  - **Optimization**: Machine learning-based workflow optimization
  - **Execution**: Workflow execution with dependency resolution and parallel processing

  ## Key Modules

  - `ExOrchestrator.WorkflowComposer` - High-level workflow composition
  - `ExOrchestrator.HTDAG` - Goal decomposition and task graph management
  - `ExOrchestrator.Notifications` - Real-time event broadcasting
  - `ExOrchestrator.Executor` - Workflow execution with monitoring
  - `ExOrchestrator.FlowBuilder` - Dynamic workflow creation
  - `ExOrchestrator.HTDAGOptimizer` - Workflow optimization and learning
  """

  require Logger

  @doc """
  Get the current version of ExOrchestrator.
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:ex_orchestrator, :vsn)
    |> to_string()
  end

  @doc """
  Get system information and capabilities.
  """
  @spec system_info() :: map()
  def system_info do
    %{
      version: version(),
      features: get_enabled_features(),
      capabilities: get_capabilities(),
      configuration: get_configuration_summary()
    }
  end

  @doc """
  Check if a feature is enabled.
  """
  @spec feature_enabled?(atom()) :: boolean()
  def feature_enabled?(feature) do
    ExOrchestrator.Config.feature_enabled?(feature)
  end

  @doc """
  Get configuration for a specific component.
  """
  @spec get_config(atom() | list(atom()), keyword()) :: any()
  def get_config(key, opts \\ []) do
    ExOrchestrator.Config.get(key, opts)
  end

  # Private functions

  defp get_enabled_features do
    %{
      monitoring: feature_enabled?(:monitoring),
      optimization: feature_enabled?(:optimization),
      notifications: feature_enabled?(:notifications),
      learning: feature_enabled?(:learning),
      real_time: feature_enabled?(:real_time)
    }
  end

  defp get_capabilities do
    %{
      goal_decomposition: true,
      workflow_execution: true,
      message_queuing: true,
      real_time_notifications: true,
      workflow_optimization: feature_enabled?(:optimization),
      machine_learning: feature_enabled?(:learning),
      parallel_execution: true,
      dependency_resolution: true,
      event_broadcasting: feature_enabled?(:notifications)
    }
  end

  defp get_configuration_summary do
    %{
      max_depth: get_config(:max_depth),
      timeout: get_config(:timeout),
      max_parallel: get_config(:max_parallel),
      retry_attempts: get_config(:retry_attempts)
    }
  end
end