defmodule Singularity.Nif.AnalysisSuite do
  @moduledoc """
  Analysis Suite NIF - Direct Rust NIF bindings for code analysis

  This module provides direct NIF bindings to the Rust analysis-suite.
  It's separate from the main AnalysisSuite module to keep NIF concerns isolated.

  ## NIF Functions:
  - `analyze_code_nif/2` - Pure computation code analysis
  - `calculate_quality_metrics_nif/2` - Quality metrics calculation
  """

  require Logger

  # NIF module - will be loaded from Rust
  use Rustler, otp_app: :singularity, crate: :analysis_suite

  @doc """
  Analyze code using Rust analysis-suite (pure computation)
  """
  @spec analyze_code_nif(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def analyze_code_nif(codebase_path, language) do
    case analyze_code_nif(codebase_path, language) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculate quality metrics using Rust analysis-suite (pure computation)
  """
  @spec calculate_quality_metrics_nif(String.t() | nil, String.t()) :: {:ok, map()} | {:error, String.t()}
  def calculate_quality_metrics_nif(code, language) do
    case calculate_quality_metrics_nif(code, language) do
      {:ok, metrics} -> {:ok, metrics}
      {:error, reason} -> {:error, reason}
    end
  end

  # NIF function stubs - will be implemented in Rust
  defp analyze_code_nif(_codebase_path, _language), do: :erlang.nif_error(:nif_not_loaded)
  defp calculate_quality_metrics_nif(_code, _language), do: :erlang.nif_error(:nif_not_loaded)
end