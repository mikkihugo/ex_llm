defmodule Singularity.MetaRegistry.Frameworks.RustNif do
  @moduledoc """
  Rust NIF framework learning patterns.

  Learns from Rust NIF patterns to improve our NIF usage.
  """

  alias Singularity.MetaRegistry.QuerySystem

  @doc """
  Learn from Rust NIF patterns.

  ## Examples

      # Learn from our Rust NIFs
      learn_patterns(%{
        modules: ["ArchitectureEngine", "CodeEngine", "EmbeddingEngine"],
        functions: ["analyze_architecture", "detect_patterns", "generate_embeddings"],
        types: ["Result<", "Option<", "Vec<", "HashMap<"],
        patterns: ["pub fn", "use rustler", "rustler::init!"]
      })
  """
  def learn_patterns(attrs) do
    QuerySystem.learn_naming_patterns("rust-nif-framework", %{
      language: "rust",
      framework: "rustler",
      patterns: attrs.patterns
    })
  end

  @doc """
  Get Rust NIF suggestions based on learned patterns.

  ## Examples

      # Get module suggestions
      get_suggestions("parser", "module")
      # Returns: ["ParserEngine", "CodeParser", "SyntaxParser"]
      
      # Get function suggestions
      get_suggestions("analyze", "function")
      # Returns: ["analyze_code", "analyze_architecture", "analyze_patterns"]
  """
  def get_suggestions(context, type) do
    QuerySystem.query_naming_suggestions("rust-nif-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "module" -> "#{pattern}Engine"
        "function" -> "#{pattern}_#{context}"
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize Rust NIF framework patterns.
  """
  def initialize_patterns do
    learn_patterns(%{
      modules: ["ArchitectureEngine", "CodeEngine", "EmbeddingEngine"],
      functions: ["analyze_architecture", "detect_patterns", "generate_embeddings"],
      types: ["Result<", "Option<", "Vec<", "HashMap<"],
      patterns: [
        "pub fn",
        "use rustler",
        "rustler::init!",
        "pub struct",
        "pub enum",
        "impl"
      ]
    })
  end
end
