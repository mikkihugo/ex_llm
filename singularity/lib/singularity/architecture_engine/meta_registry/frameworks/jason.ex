defmodule Singularity.MetaRegistry.Frameworks.Jason do
  @moduledoc """
  Jason framework learning patterns.

  Learns from Jason JSON patterns to improve our JSON handling.
  """

  alias Singularity.MetaRegistry.QuerySystem

  @doc """
  Learn from Jason JSON patterns.

  ## Examples

      # Learn from our JSON handling
      learn_patterns(%{
        functions: ["encode!", "decode!", "encode", "decode"],
        patterns: ["@derive {Jason.Encoder}", "Jason.Encoder", "only: @fields"]
      })
  """
  def learn_patterns(attrs) do
    QuerySystem.learn_naming_patterns("jason-framework", %{
      language: "elixir",
      framework: "jason",
      patterns: attrs.patterns
    })
  end

  @doc """
  Get Jason suggestions based on learned patterns.

  ## Examples

      # Get function suggestions
      get_suggestions("user", "function")
      # Returns: ["encode_user!", "decode_user!", "encode_user", "decode_user"]
      
      # Get pattern suggestions
      get_suggestions("user", "pattern")
      # Returns: ["@derive {Jason.Encoder}", "Jason.Encoder", "only: @fields"]
  """
  def get_suggestions(context, type) do
    QuerySystem.query_naming_suggestions("jason-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "function" -> "#{pattern}_#{context}"
        "pattern" -> pattern
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize Jason framework patterns.
  """
  def initialize_patterns do
    learn_patterns(%{
      functions: ["encode!", "decode!", "encode", "decode"],
      patterns: [
        "@derive {Jason.Encoder}",
        "Jason.Encoder",
        "only: @fields",
        "Jason.encode!",
        "Jason.decode!",
        "Jason.encode",
        "Jason.decode"
      ]
    })
  end
end
