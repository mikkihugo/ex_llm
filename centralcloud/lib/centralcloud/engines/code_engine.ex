defmodule Centralcloud.Engines.CodeEngine do
  @moduledoc """
  Code Engine - Delegates to Singularity via NATS.

  This module provides a simple interface to Singularity's Rust code
  analysis engine via NATS messaging. CentralCloud does not compile its own
  copy of the Rust NIF; instead it uses the Singularity instance's compiled
  engines through the SharedEngineService.
  """

  alias Centralcloud.Engines.SharedEngineService
  require Logger

  @doc """
  Analyze codebase for business domains and patterns.

  Delegates to Singularity via NATS for the actual computation.
  """
  def analyze_codebase(codebase_info, opts \\ []) do
    analysis_types = Keyword.get(opts, :analysis_types, ["business_domains", "patterns", "architecture"])
    include_embeddings = Keyword.get(opts, :include_embeddings, true)

    request = %{
      "codebase_info" => codebase_info,
      "analysis_types" => analysis_types,
      "include_embeddings" => include_embeddings
    }

    SharedEngineService.call_code_engine("analyze_codebase", request, timeout: 30_000)
  end

  @doc """
  Detect business domains in codebase.

  Delegates to Singularity via NATS for the actual computation.
  """
  def detect_business_domains(codebase_info, opts \\ []) do
    request = %{
      "codebase_info" => codebase_info,
      "confidence_threshold" => Keyword.get(opts, :confidence_threshold, 0.7)
    }

    SharedEngineService.call_code_engine("detect_business_domains", request, timeout: 30_000)
  end
end
