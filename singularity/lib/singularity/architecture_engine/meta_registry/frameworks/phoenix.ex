defmodule Singularity.MetaRegistry.Frameworks.Phoenix do
  @moduledoc """
  Phoenix framework learning patterns.

  Learns from Phoenix web patterns to improve our web development.
  """

  alias Singularity.MetaRegistry.QuerySystem

  @doc """
  Learn from Phoenix web patterns.

  ## Examples

      # Learn from our Phoenix modules
      learn_patterns(%{
        modules: ["Phoenix.Controller", "Phoenix.LiveView", "Phoenix.Channel"],
        functions: ["render", "assign", "put_flash", "redirect"],
        patterns: ["defmodule", "use Phoenix.Controller", "def index"]
      })
  """
  def learn_patterns(attrs) do
    QuerySystem.learn_naming_patterns("phoenix-framework", %{
      language: "elixir",
      framework: "phoenix",
      patterns: attrs.patterns
    })
  end

  @doc """
  Get Phoenix suggestions based on learned patterns.

  ## Examples

      # Get module suggestions
      get_suggestions("user", "module")
      # Returns: ["UserController", "UserLiveView", "UserChannel"]
      
      # Get function suggestions
      get_suggestions("user", "function")
      # Returns: ["render_user", "assign_user", "put_user_flash"]
  """
  def get_suggestions(context, type) do
    QuerySystem.query_naming_suggestions("phoenix-framework", type)
    |> Enum.map(fn pattern ->
      case type do
        "module" -> "#{context}#{pattern}"
        "function" -> "#{pattern}_#{context}"
        _ -> pattern
      end
    end)
  end

  @doc """
  Initialize Phoenix framework patterns.
  """
  def initialize_patterns do
    learn_patterns(%{
      modules: ["Phoenix.Controller", "Phoenix.LiveView", "Phoenix.Channel"],
      functions: ["render", "assign", "put_flash", "redirect"],
      patterns: [
        "defmodule",
        "use Phoenix.Controller",
        "def index",
        "def render",
        "def mount",
        "def handle_event"
      ]
    })
  end
end
