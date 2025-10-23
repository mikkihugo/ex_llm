defmodule Centralcloud.Engines.PromptEngine do
  @moduledoc """
  Prompt Engine NIF - Direct bindings to Rust prompt generation.

  This module loads the shared Rust NIF from the project root rust/ directory,
  allowing CentralCloud to use the same compiled prompt engine as Singularity.
  """

  use Rustler,
    otp_app: :centralcloud,
    crate: :prompt_engine,
    path: "../../rust/prompt_engine"

  require Logger

  @doc """
  Generate AI prompts using Rust Prompt Engine.
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

    case prompt_engine_call("generate_prompt", request) do
      {:ok, results} ->
        Logger.debug("Prompt engine generated prompt",
          prompt_type: prompt_type,
          length: String.length(Map.get(results, "prompt", ""))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Prompt engine failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Optimize existing prompt.
  """
  def optimize_prompt(prompt, opts \\ []) do
    optimization_goals = Keyword.get(opts, :optimization_goals, ["clarity", "effectiveness"])
    target_length = Keyword.get(opts, :target_length, nil)

    request = %{
      "prompt" => prompt,
      "optimization_goals" => optimization_goals,
      "target_length" => target_length
    }

    case prompt_engine_call("optimize_prompt", request) do
      {:ok, results} ->
        Logger.debug("Prompt engine optimized prompt",
          original_length: String.length(prompt),
          optimized_length: String.length(Map.get(results, "optimized_prompt", ""))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Prompt engine failed", reason: reason)
        {:error, reason}
    end
  end

  # NIF function (loaded from shared Rust crate)
  defp prompt_engine_call(_operation, _request), do: :erlang.nif_error(:nif_not_loaded)
end
