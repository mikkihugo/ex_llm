defmodule Singularity.Tools.WebSearch do
  @moduledoc """
  Web search tool that uses LLM provider APIs with built-in search.

  Replaces SERP API - uses:
  - Gemini HTTP API (has Brave Search integration)
  - Copilot API (has web search)

  NOT available for CLI clients (Claude CLI, Codex CLI, Cursor CLI)
  as they can't expose web search to our Elixir tools.

  For Codex CLI: Ensure it's started with web search enabled via config.
  """

  alias Singularity.LLM.Service
  alias Singularity.Schemas.Tools.Tool

  @doc """
  Register web search tool.

  Returns a Tool struct that can be registered in the tool registry.
  """
  def register do
    Tool.new!(%{
      name: "web_search",
      description:
        "Search the web for current information. Uses Gemini or Copilot API with built-in search capabilities.",
      parameters_schema: %{
        "type" => "object",
        "properties" => %{
          "query" => %{
            "type" => "string",
            "description" => "The search query"
          },
          "max_results" => %{
            "type" => "integer",
            "description" => "Maximum number of results to return (default: 5)"
          }
        },
        "required" => ["query"]
      },
      function: &execute/2
    })
  end

  @doc """
  Execute web search using LLM provider with search capability.

  ## Arguments

  - query: Search query string
  - max_results: Max results to return (default: 5)

  ## Context

  Should include:
  - mcp_client: Which MCP client is calling (claude, cursor, codex)
  - correlation_id: For tracking

  ## Returns

  {:ok, search_results_text} or {:error, reason}
  """
  def execute(args, context) do
    query = args["query"]
    max_results = args["max_results"] || 5
    mcp_client = context[:mcp_client] || "direct"

    # Check if client supports web search via our tool
    case get_search_provider(mcp_client) do
      {:ok, provider} ->
        perform_search(provider, query, max_results, context)

      {:error, :not_supported} ->
        {:error,
         "Web search not available for client '#{mcp_client}'. This tool only works with HTTP API clients (Gemini, Copilot), not CLI clients."}
    end
  end

  ## Private Functions

  defp get_search_provider(mcp_client) do
    case mcp_client do
      # HTTP APIs with search
      client when client in ["gemini", "copilot", "direct"] ->
        # Prefer Gemini (has Brave Search integration)
        {:ok, :gemini}

      # CLI clients - can't use our search tool
      client when client in ["claude", "claude-code", "cursor", "cursor-agent", "codex"] ->
        {:error, :not_supported}

      # Unknown client - try Gemini
      _ ->
        {:ok, :gemini}
    end
  end

  defp perform_search(provider, query, max_results, context) do
    # Build search prompt
    search_prompt = """
    Search the web for: #{query}

    Provide #{max_results} relevant results with:
    - Source/URL
    - Key information found
    - Relevance to the query

    Format as a clear, structured summary.
    """

    # Call LLM with search capability via NATS
    # Use simple complexity for web search tasks
    case Service.call_with_prompt(:simple, search_prompt,
           max_tokens: 2000,
           temperature: 0.3,
           provider: provider
         ) do
      {:ok, response} ->
        {:ok, response.text}

      {:error, reason} ->
        {:error, "Web search failed: #{inspect(reason)}"}
    end
  end
end
