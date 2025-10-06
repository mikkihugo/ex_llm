defmodule Singularity.SourceCodeAnalyzer do
  @moduledoc """
  Source Code Analyzer - Rust NIF bindings for source-code-parser

  Provides pure-computation analysis from Rust with NO I/O.
  Elixir handles all PostgreSQL storage via Ecto.

  ## Architecture

  ```
  Rust (source-code-parser)
    ↓ Fast computation (CFG, graphs, metrics)
    ↓ Returns data structures
  Elixir (this module)
    ↓ Receives results via NIF
    ↓ Stores in PostgreSQL (Ecto)
  ```

  ## Usage

  ```elixir
  # Pure computation - no DB access in Rust!
  {:ok, result} = SourceCodeAnalyzer.analyze_control_flow("lib/user.ex")

  # Result:
  %ControlFlowResult{
    dead_ends: [%DeadEnd{...}],
    completeness_score: 0.75,
    has_issues: true
  }
  ```
  """

  use Rustler,
    otp_app: :singularity,
    crate: "source-code-parser",
    mode: :release,
    features: ["nif"]

  ## NIF Functions (implemented in Rust)

  @doc """
  Analyze control flow for a file

  Returns analysis results - does NOT write to database!
  Elixir code is responsible for storing results.
  """
  @spec analyze_control_flow(String.t()) ::
    {:ok, ControlFlowResult.t()} | {:error, String.t()}
  def analyze_control_flow(_file_path) do
    :erlang.nif_error(:nif_not_loaded)
  end

  ## Elixir Structs (match Rust NifStruct definitions)

  defmodule ControlFlowResult do
    @moduledoc """
    Control flow analysis result from Rust

    Maps to Rust struct in nif_bindings.rs
    """

    @type t :: %__MODULE__{
      dead_ends: [DeadEnd.t()],
      unreachable_code: [UnreachableCode.t()],
      completeness_score: float(),
      total_paths: non_neg_integer(),
      complete_paths: non_neg_integer(),
      incomplete_paths: non_neg_integer(),
      has_issues: boolean()
    }

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

  defmodule DeadEnd do
    @moduledoc """
    Dead end detected in code flow

    Maps to Rust struct in nif_bindings.rs
    """

    @type t :: %__MODULE__{
      node_id: String.t(),
      function_name: String.t(),
      line_number: non_neg_integer(),
      reason: String.t()
    }

    defstruct [:node_id, :function_name, :line_number, :reason]
  end

  defmodule UnreachableCode do
    @moduledoc """
    Unreachable code detected

    Maps to Rust struct in nif_bindings.rs
    """

    @type t :: %__MODULE__{
      node_id: String.t(),
      line_number: non_neg_integer(),
      reason: String.t()
    }

    defstruct [:node_id, :line_number, :reason]
  end
end
