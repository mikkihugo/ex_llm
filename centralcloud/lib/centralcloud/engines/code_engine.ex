defmodule Centralcloud.Engines.CodeEngine do
  @moduledoc """
  Code Engine NIF - Direct bindings to Rust code analysis.

  This module loads the shared Rust NIF from the project root rust/ directory,
  allowing CentralCloud to use the same compiled code analysis engine as Singularity.
  """

  use Rustler,
    otp_app: :centralcloud,
    crate: :code_engine,
    path: "../../../rust/code_engine"

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

    case code_engine_call("analyze_codebase", request) do
      {:ok, results} ->
        Logger.debug("Code engine analysis completed",
          business_domains: length(Map.get(results, "business_domains", [])),
          patterns: length(Map.get(results, "patterns", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Code engine failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Detect business domains in codebase.
  """
  def detect_business_domains(codebase_info, opts \\ []) do
    request = %{
      "codebase_info" => codebase_info,
      "confidence_threshold" => Keyword.get(opts, :confidence_threshold, 0.7)
    }

    case code_engine_call("detect_business_domains", request) do
      {:ok, results} ->
        Logger.debug("Code engine detected business domains",
          domains: length(Map.get(results, "business_domains", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Code engine failed", reason: reason)
        {:error, reason}
    end
  end

  # NIF function (loaded from shared Rust crate)
  defp code_engine_call(_operation, _request), do: :erlang.nif_error(:nif_not_loaded)
end
