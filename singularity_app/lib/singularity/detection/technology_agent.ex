defmodule Singularity.TechnologyAgent do
  @moduledoc """
  Stubbed technology detection agent.

  The original Rust + NATS detection pipeline is not available in this stripped
  workspace, so every entry point returns a descriptive error instead of
  attempting partial fallbacks.
  """

  require Logger

  @doc """
  Stubbed technology detection entry point.
  """
  def detect_technologies(codebase_path, _opts \\ []) do
    Logger.warning("Technology detection disabled for #{codebase_path}")
    {:error, :technology_detection_disabled}
  end

  @doc """
  Stubbed Elixir-only detection path (kept for API compatibility).
  """
  def detect_technologies_elixir(codebase_path, _opts \\ []) do
    Logger.warning("Technology detection disabled for #{codebase_path}")
    {:error, :technology_detection_disabled}
  end

  @doc """
  Stubbed category-specific detection.
  """
  def detect_technology_category(codebase_path, category, _opts \\ []) do
    Logger.warning("Technology detection disabled for #{codebase_path} (category #{inspect(category)})")
    {:error, :technology_detection_disabled}
  end

  @doc """
  Stubbed code pattern analysis helper.
  """
  def analyze_code_patterns(codebase_path, _opts \\ []) do
    Logger.warning("Technology code pattern analysis disabled for #{codebase_path}")
    {:error, :technology_detection_disabled}
  end
end
