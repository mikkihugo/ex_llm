defmodule Singularity.MetaRegistry.FrameworkRegistry do
  @moduledoc """
  Framework registry for managing all framework learning patterns.
  
  This is the main entry point for framework-specific learning and suggestions.
  Each framework has its own learning module in the frameworks/ directory.
  """

  @frameworks %{
    nats: Singularity.MetaRegistry.Frameworks.Nats,
    postgresql: Singularity.MetaRegistry.Frameworks.Postgresql,
    ets: Singularity.MetaRegistry.Frameworks.Ets,
    rust_nif: Singularity.MetaRegistry.Frameworks.RustNif,
    elixir_otp: Singularity.MetaRegistry.Frameworks.ElixirOtp,
    ecto: Singularity.MetaRegistry.Frameworks.Ecto,
    jason: Singularity.MetaRegistry.Frameworks.Jason,
    phoenix: Singularity.MetaRegistry.Frameworks.Phoenix,
    exunit: Singularity.MetaRegistry.Frameworks.ExUnit
  }

  @doc """
  Get suggestions for a specific framework.
  
  ## Examples
  
      # Get NATS suggestions
      get_suggestions(:nats, "search", "subject")
      # Returns: ["search.semantic", "search.hybrid", "search.vector"]
      
      # Get PostgreSQL suggestions
      get_suggestions(:postgresql, "user", "table")
      # Returns: ["user_profiles", "user_sessions", "user_preferences"]
      
      # Get Rust NIF suggestions
      get_suggestions(:rust_nif, "parser", "module")
      # Returns: ["ParserEngine", "CodeParser", "SyntaxParser"]
  """
  def get_suggestions(framework, context, type) do
    case Map.get(@frameworks, framework) do
      nil -> {:error, "Unknown framework: #{framework}"}
      module -> module.get_suggestions(context, type)
    end
  end

  @doc """
  Learn patterns for a specific framework.
  
  ## Examples
  
      # Learn NATS patterns
      learn_patterns(:nats, %{
        subjects: ["llm.provider.claude", "code.analysis.parse"],
        messaging: ["request/response", "pub/sub"],
        patterns: ["subject.hierarchy", "wildcard.subjects"]
      })
      
      # Learn PostgreSQL patterns
      learn_patterns(:postgresql, %{
        tables: ["code_chunks", "technology_detections"],
        queries: ["SELECT", "INSERT", "UPDATE"],
        patterns: ["codebase_id", "snapshot_id", "metadata"]
      })
  """
  def learn_patterns(framework, attrs) do
    case Map.get(@frameworks, framework) do
      nil -> {:error, "Unknown framework: #{framework}"}
      module -> module.learn_patterns(attrs)
    end
  end

  @doc """
  Initialize patterns for a specific framework.
  
  ## Examples
  
      # Initialize NATS patterns
      initialize_framework(:nats)
      
      # Initialize PostgreSQL patterns
      initialize_framework(:postgresql)
  """
  def initialize_framework(framework) do
    case Map.get(@frameworks, framework) do
      nil -> {:error, "Unknown framework: #{framework}"}
      module -> module.initialize_patterns()
    end
  end

  @doc """
  Initialize all framework patterns.
  
  ## Examples
  
      # Initialize all frameworks
      initialize_all_frameworks()
  """
  def initialize_all_frameworks do
    @frameworks
    |> Map.keys()
    |> Enum.map(&initialize_framework/1)
    |> Enum.reduce(:ok, fn
      :ok, :ok -> :ok
      {:error, reason}, _ -> {:error, reason}
      _, {:error, reason} -> {:error, reason}
    end)
  end

  @doc """
  Get all available frameworks.
  
  ## Examples
  
      # Get all frameworks
      get_available_frameworks()
      # Returns: [:nats, :postgresql, :ets, :rust_nif, :elixir_otp, :ecto, :jason, :phoenix, :exunit]
  """
  def get_available_frameworks do
    Map.keys(@frameworks)
  end

  @doc """
  Check if a framework is available.
  
  ## Examples
  
      # Check if NATS is available
      framework_available?(:nats)
      # Returns: true
      
      # Check if unknown framework is available
      framework_available?(:unknown)
      # Returns: false
  """
  def framework_available?(framework) do
    Map.has_key?(@frameworks, framework)
  end
end