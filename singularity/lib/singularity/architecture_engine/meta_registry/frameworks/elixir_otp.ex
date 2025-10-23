defmodule Singularity.MetaRegistry.Frameworks.ElixirOtp do
  @moduledoc """
  Elixir OTP framework learning patterns.

  Learns from Elixir OTP patterns to improve our OTP usage.
  """

  alias Singularity.MetaRegistry.QuerySystem

  @doc """
  Learn from Elixir OTP patterns.

  ## Examples

      # Learn from our OTP modules
      learn_patterns(%{
        modules: ["GenServer", "Supervisor", "Agent", "Task"],
        functions: ["start_link", "init", "handle_call", "handle_cast"],
        patterns: ["defmodule", "use GenServer", "def start_link"]
      })
  """
  def learn_patterns(attrs) do
    QuerySystem.learn_naming_patterns("elixir-otp-framework", %{
      language: "elixir",
      framework: "otp",
      patterns: attrs.patterns
    })
  end

  @doc """
  Get Elixir OTP suggestions based on learned patterns.

  ## Examples

      # Get module suggestions
      get_suggestions("user", "module")
      # Returns: ["User.Server", "User.Supervisor", "User.Agent"]
      
      # Get function suggestions
      get_suggestions("user", "function")
      # Returns: ["start_user", "init_user", "handle_user_call"]
  """
  def get_suggestions(context, type) do
    QuerySystem.query_naming_suggestions("elixir-otp-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "module" -> "#{context}.#{pattern}"
        "function" -> "#{pattern}_#{context}"
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize Elixir OTP framework patterns.
  """
  def initialize_patterns do
    learn_patterns(%{
      modules: ["GenServer", "Supervisor", "Agent", "Task"],
      functions: ["start_link", "init", "handle_call", "handle_cast"],
      patterns: [
        "defmodule",
        "use GenServer",
        "def start_link",
        "def init",
        "def handle_call",
        "def handle_cast"
      ]
    })
  end
end
