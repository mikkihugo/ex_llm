# Backwards Compatibility Module
# This module is an alias for Singularity.Agents.Agent
# It allows existing code that uses Singularity.Agent to continue working

defmodule Singularity.Agent do
  @moduledoc """
  Backwards compatibility module.

  This module delegates all calls to `Singularity.Agents.Agent`.

  **Note:** New code should use `Singularity.Agents.Agent` directly.
  This module is provided only for backwards compatibility with existing code.
  """

  defdelegate start_link(opts), to: Singularity.Agents.Agent
  defdelegate execute_task(agent_id, task_name, context), to: Singularity.Agents.Agent
  defdelegate child_spec(opts), to: Singularity.Agents.Agent
  defdelegate improve(agent_id, payload), to: Singularity.Agents.Agent
  defdelegate update_metrics(agent_id, metrics), to: Singularity.Agents.Agent
  defdelegate record_outcome(agent_id, outcome), to: Singularity.Agents.Agent
  defdelegate force_improvement(agent_id, reason), to: Singularity.Agents.Agent
  defdelegate get_state(agent_id), to: Singularity.Agents.Agent
end
