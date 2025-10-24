defmodule Singularity.LintingEngine do
  @moduledoc """
  Linting Engine - Multi-language linting and quality gates.

  This module wraps the Rust NIF from rust/linting_engine which provides:
  - Multi-language linting integration (ESLint, Clippy, Credo, etc.)
  - Quality gate enforcement
  - External linter coordination
  - Multi-language support (Elixir, Rust, TypeScript, Python, etc.)

  The Rust NIF handles heavy linting work while Elixir coordinates workflows.
  """

  use Rustler,
    otp_app: :singularity,
    crate: :linting_engine,
    path: "../rust/linting_engine",
    # Temporarily skip compilation to fix hot reload
    skip_compilation?: true

  require Logger
  alias Singularity.NATS.Client, as: NatsClient

  @behaviour Singularity.Engine

  @impl Singularity.Engine
  def id, do: :quality

  @impl Singularity.Engine
  def label, do: "Quality Engine"

  @impl Singularity.Engine
  def description,
    do: "Rust-powered multi-language quality analysis with comprehensive linter support."

  @impl Singularity.Engine
  def capabilities do
    [
      %{
        id: :analysis,
        label: "Code Quality Analysis",
        description: "Analyze code for readability, maintainability, and quality metrics.",
        available?: nif_loaded?(),
        tags: [:quality, :analysis, :rust_nif]
      },
      %{
        id: :gates,
        label: "Quality Gates",
        description: "Enforce quality thresholds and project-level gates.",
        available?: nif_loaded?(),
        tags: [:quality, :gates, :rust_nif]
      },
      %{
        id: :ai_patterns,
        label: "AI Pattern Detection",
        description: "Detect AI-specific code patterns and anti-patterns.",
        available?: nif_loaded?(),
        tags: [:quality, :ai, :rust_nif]
      },
      %{
        id: :multi_language,
        label: "Multi-Language Support",
        description: "Analyze code in Elixir, Rust, TypeScript, Python, and more.",
        available?: nif_loaded?(),
        tags: [:quality, :languages, :rust_nif]
      }
    ]
  end

  @impl Singularity.Engine
  def health do
    if nif_loaded?(), do: :ok, else: {:error, :nif_not_loaded}
  end

  # NIF functions (replaced by Rust implementation)
  def analyze_code_quality(_code, _language), do: :erlang.nif_error(:nif_not_loaded)
  def run_quality_gates(_project_path), do: :erlang.nif_error(:nif_not_loaded)
  def calculate_quality_metrics(_code, _language), do: :erlang.nif_error(:nif_not_loaded)
  def detect_ai_patterns(_code, _language), do: :erlang.nif_error(:nif_not_loaded)
  def get_quality_config(), do: :erlang.nif_error(:nif_not_loaded)
  def update_quality_config(_config), do: :erlang.nif_error(:nif_not_loaded)
  def get_supported_languages(), do: :erlang.nif_error(:nif_not_loaded)
  def get_quality_rules(_category), do: :erlang.nif_error(:nif_not_loaded)
  def add_quality_rule(_rule), do: :erlang.nif_error(:nif_not_loaded)
  def remove_quality_rule(_rule_name), do: :erlang.nif_error(:nif_not_loaded)
  def get_version(), do: :erlang.nif_error(:nif_not_loaded)
  def health_check(), do: :erlang.nif_error(:nif_not_loaded)

  # Helper to check if NIF loaded
  defp nif_loaded? do
    try do
      get_version()
      true
    rescue
      _ -> false
    end
  end

  # Central Cloud Integration via Singularity.NatsClient

  @doc """
  Query central quality service for quality rules and patterns.
  """
  def query_central_quality_rules(language, quality_level) do
    request = %{
      action: "get_quality_rules",
      language: language,
      quality_level: quality_level,
      include_patterns: true
    }

    case Singularity.NATS.Client.request("central.quality.rules", Jason.encode!(request), timeout: 5000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data["rules"] || []}
          {:error, reason} -> {:error, "Failed to decode central response: #{reason}"}
        end

      {:error, reason} ->
        {:error, "NATS request failed: #{reason}"}
    end
  end

  @doc """
  Send quality analysis results to central for learning and analytics.
  """
  def send_quality_analytics(results) do
    request = %{
      action: "record_analysis",
      results: results,
      timestamp: DateTime.utc_now()
    }

    case Singularity.NATS.Client.publish("central.quality.analytics", Jason.encode!(request)) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to send quality analytics: #{reason}"}
    end
  end

  @doc """
  Get quality recommendations from central based on code patterns.
  """
  def get_quality_recommendations(code_snippet, language) do
    request = %{
      action: "get_recommendations",
      code_snippet: code_snippet,
      language: language,
      include_examples: true
    }

    case Singularity.NATS.Client.request("central.quality.recommendations", Jason.encode!(request),
           timeout: 3000
         ) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data["recommendations"] || []}
          {:error, reason} -> {:error, "Failed to decode central response: #{reason}"}
        end

      {:error, reason} ->
        {:error, "NATS request failed: #{reason}"}
    end
  end
end
