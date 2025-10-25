defmodule Pgflow.DAG.WorkflowDefinition do
  @moduledoc """
  Parses and validates workflow step definitions with DAG support.

  Handles both legacy sequential syntax and new depends_on syntax:

  ## Sequential Syntax (Legacy, Backwards Compatible)

      def __workflow_steps__ do
        [
          {:step1, &__MODULE__.step1/1},
          {:step2, &__MODULE__.step2/1}
        ]
      end

  Automatically converts to: step2 depends_on step1

  ## DAG Syntax (New, Parallel Support)

      def __workflow_steps__ do
        [
          {:fetch_data, &__MODULE__.fetch_data/1, depends_on: []},
          {:analyze, &__MODULE__.analyze/1, depends_on: [:fetch_data]},
          {:summarize, &__MODULE__.summarize/1, depends_on: [:fetch_data]},
          {:save, &__MODULE__.save/1, depends_on: [:analyze, :summarize]}
        ]
      end

  ## Validation

  - Detects cycles in dependency graph
  - Validates all dependencies exist
  - Ensures root steps exist (steps with no dependencies)
  """

  defstruct [:steps, :dependencies, :root_steps, :slug]

  @type step_definition :: {atom(), function(), keyword()}
  @type t :: %__MODULE__{
          steps: %{atom() => function()},
          dependencies: %{atom() => [atom()]},
          root_steps: [atom()],
          slug: String.t()
        }

  @doc """
  Parses workflow step definitions into a validated DAG structure.
  """
  @spec parse(module()) :: {:ok, t()} | {:error, term()}
  def parse(workflow_module) do
    steps_list = workflow_module.__workflow_steps__()
    workflow_slug = to_string(workflow_module)

    with {:ok, parsed} <- parse_steps(steps_list),
         :ok <- validate_dependencies(parsed.steps, parsed.dependencies),
         :ok <- validate_no_cycles(parsed.dependencies),
         {:ok, root_steps} <- find_root_steps(parsed.dependencies) do
      {:ok,
       %__MODULE__{
         steps: parsed.steps,
         dependencies: parsed.dependencies,
         root_steps: root_steps,
         slug: workflow_slug
       }}
    end
  end

  # Parse step definitions, handling both legacy and new syntax
  defp parse_steps(steps_list) do
    {steps, dependencies, _prev_step} =
      Enum.reduce(steps_list, {%{}, %{}, nil}, fn step_def, {steps_acc, deps_acc, prev_step} ->
        case step_def do
          # New syntax: {step_name, step_fn, depends_on: [deps]}
          {step_name, step_fn, opts} when is_atom(step_name) and is_function(step_fn) ->
            depends_on = Keyword.get(opts, :depends_on, [])

            {
              Map.put(steps_acc, step_name, step_fn),
              Map.put(deps_acc, step_name, depends_on),
              step_name
            }

          # Legacy syntax: {step_name, step_fn} - auto-add dependency on previous step
          {step_name, step_fn} when is_atom(step_name) and is_function(step_fn) ->
            depends_on = if prev_step, do: [prev_step], else: []

            {
              Map.put(steps_acc, step_name, step_fn),
              Map.put(deps_acc, step_name, depends_on),
              step_name
            }

          invalid ->
            raise ArgumentError,
                  "Invalid step definition: #{inspect(invalid)}. Expected {step_name, step_fn} or {step_name, step_fn, depends_on: [...]}"
        end
      end)

    {:ok, %{steps: steps, dependencies: dependencies}}
  end

  # Validate that all dependencies reference existing steps
  defp validate_dependencies(steps, dependencies) do
    all_step_names = Map.keys(steps)

    invalid_deps =
      Enum.flat_map(dependencies, fn {step_name, deps} ->
        Enum.reject(deps, &(&1 in all_step_names))
        |> Enum.map(&{step_name, &1})
      end)

    if invalid_deps == [] do
      :ok
    else
      {:error, {:invalid_dependencies, invalid_deps}}
    end
  end

  # Validate no cycles using depth-first search
  defp validate_no_cycles(dependencies) do
    case find_cycle(dependencies) do
      nil -> :ok
      cycle -> {:error, {:cycle_detected, cycle}}
    end
  end

  defp find_cycle(dependencies) do
    all_steps = Map.keys(dependencies)

    Enum.find_value(all_steps, fn start_step ->
      case dfs_cycle(start_step, dependencies, MapSet.new(), []) do
        {:cycle, path} -> Enum.reverse([start_step | path])
        :no_cycle -> nil
      end
    end)
  end

  defp dfs_cycle(step, dependencies, visited, path) do
    cond do
      step in visited ->
        # Found a cycle
        cycle_start = Enum.find_index(path, &(&1 == step))
        {:cycle, Enum.drop(path, cycle_start || 0)}

      true ->
        new_visited = MapSet.put(visited, step)
        new_path = [step | path]
        deps = Map.get(dependencies, step, [])

        Enum.find_value(deps, :no_cycle, fn dep ->
          case dfs_cycle(dep, dependencies, new_visited, new_path) do
            {:cycle, _} = result -> result
            :no_cycle -> nil
          end
        end) || :no_cycle
    end
  end

  # Find root steps (steps with no dependencies)
  defp find_root_steps(dependencies) do
    root_steps =
      dependencies
      |> Enum.filter(fn {_step, deps} -> deps == [] end)
      |> Enum.map(fn {step, _} -> step end)

    if root_steps == [] do
      {:error, :no_root_steps}
    else
      {:ok, root_steps}
    end
  end

  @doc """
  Get all steps that depend on the given step (forward dependencies).
  """
  @spec get_dependents(t(), atom()) :: [atom()]
  def get_dependents(%__MODULE__{dependencies: dependencies}, step_name) do
    dependencies
    |> Enum.filter(fn {_step, deps} -> step_name in deps end)
    |> Enum.map(fn {step, _} -> step end)
  end

  @doc """
  Get all steps that the given step depends on (reverse dependencies).
  """
  @spec get_dependencies(t(), atom()) :: [atom()]
  def get_dependencies(%__MODULE__{dependencies: dependencies}, step_name) do
    Map.get(dependencies, step_name, [])
  end

  @doc """
  Get step function by name.
  """
  @spec get_step_function(t(), atom()) :: function() | nil
  def get_step_function(%__MODULE__{steps: steps}, step_name) do
    Map.get(steps, step_name)
  end

  @doc """
  Get count of dependencies for a step.
  """
  @spec dependency_count(t(), atom()) :: integer()
  def dependency_count(%__MODULE__{dependencies: dependencies}, step_name) do
    Map.get(dependencies, step_name, []) |> length()
  end
end
