defmodule Singularity.Agents.Coordination.AgentCapability do
  @moduledoc """
  Agent Capability Registry - Agents declare what they can do.

  Each agent registers its capabilities so the Coordination Router can:
  - Understand what each agent specializes in
  - Route goals to appropriate agents
  - Discover agent combinations for complex tasks
  - Learn which agents work best together

  ## Capability Definition

  Capabilities include:
  - **role**: Primary role (self_improve, cost_optimize, architect, technology, refactoring, chat)
  - **domains**: Areas of expertise (code_quality, testing, documentation, architecture, performance)
  - **input_types**: What kinds of input it accepts (code, design, requirements, codebase)
  - **output_types**: What it produces (code, analysis, plan, documentation)
  - **complexity_level**: simple/medium/complex work it can handle
  - **estimated_cost**: Average cost in tokens for typical task
  - **availability**: Capacity (busy, available, overloaded)
  - **success_rate**: Historical success rate (0.0-1.0)
  - **preferred_model**: preferred LLM complexity (simple, medium, complex)

  ## Example

  ```elixir
  %AgentCapability{
    agent_name: :refactoring_agent,
    role: :refactoring,
    domains: [:code_quality, :testing, :documentation],
    input_types: [:code, :codebase],
    output_types: [:code, :documentation],
    complexity_level: :medium,
    estimated_cost: 500,
    availability: :available,
    success_rate: 0.92,
    preferred_model: :medium,
    tags: [:async_safe, :idempotent, :parallelizable]
  }
  ```
  """

  defstruct [
    :agent_name,
    :role,
    :domains,
    :input_types,
    :output_types,
    :complexity_level,
    :estimated_cost,
    :availability,
    :success_rate,
    :preferred_model,
    tags: [],
    metadata: %{}
  ]

  @type role ::
    :self_improve | :cost_optimize | :architect | :technology | :refactoring | :chat | :quality_enforcer

  @type domain ::
    :code_quality | :testing | :documentation | :architecture | :performance |
    :security | :refactoring | :knowledge | :learning | :monitoring

  @type input_type :: :code | :design | :requirements | :codebase | :metrics | :feedback

  @type output_type :: :code | :analysis | :plan | :documentation | :metrics | :decision

  @type complexity :: :simple | :medium | :complex

  @type availability :: :available | :busy | :overloaded | :offline

  @type t :: %__MODULE__{
    agent_name: atom(),
    role: role(),
    domains: [domain()],
    input_types: [input_type()],
    output_types: [output_type()],
    complexity_level: complexity(),
    estimated_cost: non_neg_integer(),
    availability: availability(),
    success_rate: float(),
    preferred_model: complexity(),
    tags: [atom()],
    metadata: map()
  }

  @doc """
  Create a new agent capability descriptor.
  """
  def new(agent_name, attrs) when is_atom(agent_name) and is_map(attrs) do
    %__MODULE__{
      agent_name: agent_name,
      role: attrs[:role] || :chat,
      domains: attrs[:domains] || [],
      input_types: attrs[:input_types] || [:code],
      output_types: attrs[:output_types] || [:analysis],
      complexity_level: attrs[:complexity_level] || :medium,
      estimated_cost: attrs[:estimated_cost] || 100,
      availability: attrs[:availability] || :available,
      success_rate: attrs[:success_rate] || 0.8,
      preferred_model: attrs[:preferred_model] || :medium,
      tags: attrs[:tags] || [],
      metadata: attrs[:metadata] || %{}
    }
  end

  @doc """
  Check if agent can handle a specific domain.
  """
  def can_handle_domain?(%__MODULE__{domains: domains}, domain) do
    Enum.member?(domains, domain)
  end

  @doc """
  Check if agent produces required output type.
  """
  def produces_output?(%__MODULE__{output_types: outputs}, output_type) do
    Enum.member?(outputs, output_type)
  end

  @doc """
  Check if agent accepts required input type.
  """
  def accepts_input?(%__MODULE__{input_types: inputs}, input_type) do
    Enum.member?(inputs, input_type)
  end

  @doc """
  Check if agent is available for new work.
  """
  def is_available?(%__MODULE__{availability: avail}) do
    avail in [:available, :busy]
  end

  @doc """
  Calculate agent fit score for a task (0.0-1.0).

  Higher score = better fit. Considers:
  - Domain match (0.3 weight)
  - Input/output compatibility (0.3 weight)
  - Success rate (0.2 weight)
  - Availability (0.2 weight)
  """
  def fit_score(%__MODULE__{} = capability, task) when is_map(task) do
    domain_score =
      if can_handle_domain?(capability, task[:domain]), do: 1.0, else: 0.5

    input_score =
      if accepts_input?(capability, task[:input_type]), do: 1.0, else: 0.3

    output_score =
      if produces_output?(capability, task[:output_type]), do: 1.0, else: 0.3

    availability_score =
      case capability.availability do
        :available -> 1.0
        :busy -> 0.7
        :overloaded -> 0.2
        :offline -> 0.0
      end

    # Weighted score
    (domain_score * 0.3) +
      ((input_score + output_score) / 2 * 0.3) +
      (capability.success_rate * 0.2) +
      (availability_score * 0.2)
  end

  @doc """
  Estimate total cost for agent to complete task.

  Returns estimated tokens based on:
  - Base estimated_cost
  - Task complexity multiplier
  """
  def estimate_cost(%__MODULE__{estimated_cost: base_cost}, task) when is_map(task) do
    multiplier =
      case task[:complexity] do
        :simple -> 0.5
        :medium -> 1.0
        :complex -> 2.5
        _ -> 1.0
      end

    round(base_cost * multiplier)
  end

  @doc """
  Convert to JSON for transport/storage.
  """
  def to_json(%__MODULE__{} = cap) do
    %{
      agent_name: cap.agent_name,
      role: cap.role,
      domains: cap.domains,
      input_types: cap.input_types,
      output_types: cap.output_types,
      complexity_level: cap.complexity_level,
      estimated_cost: cap.estimated_cost,
      availability: cap.availability,
      success_rate: cap.success_rate,
      preferred_model: cap.preferred_model,
      tags: cap.tags,
      metadata: cap.metadata
    }
  end

  @doc """
  Convert from JSON to capability struct.
  """
  def from_json(json) when is_map(json) do
    %__MODULE__{
      agent_name: json["agent_name"] || json[:agent_name],
      role: (json["role"] || json[:role]) |> to_atom(),
      domains: (json["domains"] || json[:domains] || []) |> Enum.map(&to_atom/1),
      input_types: (json["input_types"] || json[:input_types] || []) |> Enum.map(&to_atom/1),
      output_types: (json["output_types"] || json[:output_types] || []) |> Enum.map(&to_atom/1),
      complexity_level: (json["complexity_level"] || json[:complexity_level]) |> to_atom(),
      estimated_cost: json["estimated_cost"] || json[:estimated_cost] || 100,
      availability: (json["availability"] || json[:availability] || :available) |> to_atom(),
      success_rate: json["success_rate"] || json[:success_rate] || 0.8,
      preferred_model: (json["preferred_model"] || json[:preferred_model]) |> to_atom(),
      tags: (json["tags"] || json[:tags] || []) |> Enum.map(&to_atom/1),
      metadata: json["metadata"] || json[:metadata] || %{}
    }
  end

  defp to_atom(value) when is_atom(value), do: value
  defp to_atom(value) when is_binary(value), do: String.to_atom(value)
  defp to_atom(value), do: value
end
