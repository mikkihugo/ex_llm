defmodule Singularity.RustAnalyzer do
  @moduledoc """
  Rust NIF analyzer for code analysis.

  This module loads the code_engine NIF which provides:
  - Control flow analysis
  - Dependency graphs
  - Quality metrics

  The actual NIF is defined in rust/code_engine/src/lib.rs
  """

  use Rustler,
    otp_app: :singularity,
    crate: :code_engine,
    skip_compilation?: false

  # NIF functions (provided by rust/code_engine when compiled)
  def analyze_control_flow(_file_path), do: :erlang.nif_error(:nif_not_loaded)
end

defmodule Singularity.CodeEngine do
  @moduledoc """
  Code analysis engine - wrapper around Rust NIF.

  Delegates to Singularity.RustAnalyzer NIF for heavy lifting.
  """

  alias Singularity.RustAnalyzer

  @behaviour Singularity.Engine

  @impl Singularity.Engine
  def id, do: :code

  @impl Singularity.Engine
  def label, do: "Code Engine"

  @impl Singularity.Engine
  def description,
    do: "Rust-powered code analysis: control flow, dependencies, quality metrics."

  @impl Singularity.Engine
  def capabilities do
    [
      %{
        id: :control_flow,
        label: "Control Flow Analysis",
        description: "Detect dead ends, unreachable code, and incomplete paths.",
        available?: nif_loaded?(),
        tags: [:analysis, :rust_nif]
      }
    ]
  end

  @impl Singularity.Engine
  def health do
    if nif_loaded?(), do: :ok, else: {:error, :nif_not_loaded}
  end

  # Public API - delegates to NIF
  def analyze_control_flow(file_path) do
    RustAnalyzer.analyze_control_flow(file_path)
  end

  # Helper to check if NIF loaded
  defp nif_loaded? do
    try do
      RustAnalyzer.analyze_control_flow("/dev/null")
      true
    rescue
      _ -> false
    end
  end
end

# Result structs matching Rust NIF definitions
defmodule Singularity.RustAnalyzer.ControlFlowResult do
  @moduledoc "Control flow analysis result from Rust NIF"
  defstruct [
    :dead_ends,
    :unreachable_code,
    :completeness_score,
    :total_paths,
    :complete_paths,
    :incomplete_paths,
    :has_issues
  ]
end

defmodule Singularity.RustAnalyzer.DeadEnd do
  @moduledoc "Dead end information from control flow analysis"
  defstruct [:node_id, :function_name, :line_number, :reason]
end

defmodule Singularity.RustAnalyzer.UnreachableCode do
  @moduledoc "Unreachable code information"
  defstruct [:node_id, :line_number, :reason]
end
