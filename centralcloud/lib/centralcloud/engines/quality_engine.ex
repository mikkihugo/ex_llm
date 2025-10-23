defmodule Centralcloud.Engines.QualityEngine do
  @moduledoc """
  Quality Engine - Delegates to Singularity via NATS.

  This module provides a simple interface to Singularity's Rust quality
  analysis engine via NATS messaging. CentralCloud does not compile its own
  copy of the Rust NIF; instead it uses the Singularity instance's compiled
  engines through the SharedEngineService.
  """

  alias Centralcloud.Engines.SharedEngineService
  require Logger

  @doc """
  Analyze code quality using Singularity's Rust Quality Engine.

  Delegates to Singularity via NATS for the actual computation.
  """
  def analyze_quality(codebase_info, opts \\ []) do
    quality_checks = Keyword.get(opts, :quality_checks, ["maintainability", "performance", "security", "architecture"])
    include_metrics = Keyword.get(opts, :include_metrics, true)

    request = %{
      "codebase_info" => codebase_info,
      "quality_checks" => quality_checks,
      "include_metrics" => include_metrics
    }

    SharedEngineService.call_quality_engine("analyze_quality", request, timeout: 30_000)
  end

  @doc """
  Run linting on codebase.

  Delegates to Singularity via NATS for the actual computation.
  """
  def run_linting(codebase_info, opts \\ []) do
    languages = Keyword.get(opts, :languages, ["elixir", "rust", "javascript"])
    strict_mode = Keyword.get(opts, :strict_mode, false)

    request = %{
      "codebase_info" => codebase_info,
      "languages" => languages,
      "strict_mode" => strict_mode
    }

    SharedEngineService.call_quality_engine("run_linting", request, timeout: 30_000)
  end
end
