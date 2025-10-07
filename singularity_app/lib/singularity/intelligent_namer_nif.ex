defmodule Singularity.IntelligentNamerNif do
  @moduledoc """
  NIF wrapper for Rust intelligent namer.

  Calls into rust/intelligent_namer crate via Rustler.
  """

  use Rustler,
    otp_app: :singularity,
    crate: "intelligent_namer",
    path: Path.join([__DIR__, "..", "..", "..", "rust", "intelligent_namer"])

  # Elixir structs matching Rust NifStruct definitions

  defmodule Suggestion do
    @type t :: %__MODULE__{
            name: String.t(),
            confidence: float(),
            reasoning: String.t(),
            method: String.t(),
            alternatives: [String.t()]
          }

    defstruct [:name, :confidence, :reasoning, :method, :alternatives]
  end

  defmodule NamingPatterns do
    @type t :: %__MODULE__{
            language: String.t(),
            conventions: map(),
            examples: [String.t()]
          }

    defstruct [:language, :conventions, :examples]
  end

  # NIF functions (replaced by Rust at runtime)

  @doc """
  Suggest better names for a code element.

  ## Examples

      iex> context = %{
      ...>   base_name: "data",
      ...>   element_type: "variable",
      ...>   context: "user session",
      ...>   language: "elixir"
      ...> }
      iex> IntelligentNamerNif.suggest_names(context)
      {:ok, [%Suggestion{name: "user_session", confidence: 0.92, ...}]}
  """
  def suggest_names(context) do
    # This will be replaced by the Rust NIF at runtime
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Validate a name against naming conventions.

  ## Examples

      iex> IntelligentNamerNif.validate_name("UserService", "module")
      true

      iex> IntelligentNamerNif.validate_name("userService", "module")  # Wrong case for Elixir
      false
  """
  def validate_name(name, element_type) do
    # This will be replaced by the Rust NIF at runtime
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Get naming patterns for a language/framework.

  ## Examples

      iex> IntelligentNamerNif.get_naming_patterns("elixir", "phoenix")
      {:ok, %NamingPatterns{
        language: "elixir",
        conventions: %{"module" => "PascalCase", "function" => "snake_case"},
        examples: [...]
      }}
  """
  def get_naming_patterns(language, framework \\ nil) do
    # This will be replaced by the Rust NIF at runtime
    :erlang.nif_error(:nif_not_loaded)
  end
end
