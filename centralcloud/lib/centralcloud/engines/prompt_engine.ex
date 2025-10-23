defmodule Centralcloud.Engines.PromptEngine do
  @moduledoc """
  Prompt Engine - Delegates to Singularity via NATS.

  This module provides a simple interface to Singularity's Rust prompt
  generation engine via NATS messaging. CentralCloud does not compile its own
  copy of the Rust NIF; instead it uses the Singularity instance's compiled
  engines through the SharedEngineService.
  """

  alias Centralcloud.Engines.SharedEngineService
  require Logger

  @doc """
  Generate AI prompts using Singularity's Rust Prompt Engine.

  Delegates to Singularity via NATS for the actual computation.
  """
  def generate_prompt(prompt_type, context, opts \\ []) do
    template = Keyword.get(opts, :template, "default")
    optimization_level = Keyword.get(opts, :optimization_level, "balanced")

    request = %{
      "prompt_type" => prompt_type,
      "context" => context,
      "template" => template,
      "optimization_level" => optimization_level
    }

    SharedEngineService.call_prompt_engine("generate_prompt", request, timeout: 30_000)
  end

  @doc """
  Optimize existing prompt.

  Delegates to Singularity via NATS for the actual computation.
  """
  def optimize_prompt(prompt, opts \\ []) do
    optimization_goals = Keyword.get(opts, :optimization_goals, ["clarity", "effectiveness"])
    target_length = Keyword.get(opts, :target_length, nil)

    request = %{
      "prompt" => prompt,
      "optimization_goals" => optimization_goals,
      "target_length" => target_length
    }

    SharedEngineService.call_prompt_engine("optimize_prompt", request, timeout: 30_000)
  end
end
