defmodule Singularity.LLM.Config do
  @moduledoc """
  System-wide LLM configuration service for task complexity and model selection.
  
  Uses PostgreSQL Settings KV store (via Singularity.Settings) for persistence.
  Settings are sync'd from CentralCloud/Nexus, with fallback to TaskTypeRegistry/defaults.
  
  All modules that use LLM should access complexity and models through this module.
  
  ## Usage
  
      # Get task complexity for a provider
      {:ok, complexity} = Config.get_task_complexity(provider, context)
      
      # Get available models for a provider
      {:ok, models} = Config.get_models(provider, context)
  """

  alias Singularity.Settings
  alias Singularity.Repo
  import Ecto.Query

  require Jason

  @doc """
  Get task complexity for provider selection.
  
  Checks PostgreSQL Settings KV store first (sync'd from CentralCloud/Nexus), 
  falls back to TaskTypeRegistry/defaults if not found.
  
  ## Examples
  
      iex> Config.get_task_complexity("claude", %{task_type: :architect})
      {:ok, :complex}
      
      iex> Config.get_task_complexity("gemini", %{})
      {:ok, :medium}
  """
  @spec get_task_complexity(String.t() | atom(), map()) :: 
          {:ok, :simple | :medium | :complex} | {:error, term()}
  def get_task_complexity(provider, context \\ %{}) do
    provider = normalize_provider(provider)
    
    # Try PostgreSQL Settings KV store first (sync'd from CentralCloud/Nexus)
    case query_complexity_from_settings(provider, context) do
      {:ok, complexity} -> {:ok, complexity}
      {:error, :not_found} ->
        # Fallback: Try TaskTypeRegistry, then default
        task_type = Map.get(context, :task_type)
        case task_type && Singularity.MetaRegistry.TaskTypeRegistry.get_complexity(task_type) do
          nil -> {:ok, :medium}
          complexity -> {:ok, complexity}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get models for provider selection.
  
  Checks PostgreSQL Settings KV store first (sync'd from CentralCloud/Nexus), 
  falls back to default models if not found.
  
  ## Examples
  
      iex> Config.get_models("claude", %{task_type: :architect})
      {:ok, ["claude-3-5-sonnet-20241022", "claude-sonnet-4.5"]}
      
      iex> Config.get_models("gemini", %{})
      {:ok, ["gemini-2.0-flash-exp", "gemini-1.5-flash"]}
  """
  @spec get_models(String.t() | atom(), map()) :: 
          {:ok, [String.t()]} | {:error, term()}
  def get_models(provider, context \\ %{}) do
    provider = normalize_provider(provider)
    
    # Try PostgreSQL Settings KV store first (sync'd from CentralCloud/Nexus)
    case query_models_from_settings(provider, context) do
      {:ok, models} -> {:ok, models}
      {:error, :not_found} ->
        # Fallback: Use default models for provider
        default_models = get_default_models_for_provider(provider)
        {:ok, default_models}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private: PostgreSQL Settings KV store queries for complexity
  
  defp query_complexity_from_settings(provider, context) do
    # Build Settings key: "llm.providers.{provider}.complexity.{task_type}" or "llm.providers.{provider}.complexity"
    task_type = Map.get(context, :task_type)
    key = build_settings_key("llm.providers.#{provider}.complexity", task_type)
    
    case Settings.get(key) do
      nil -> {:error, :not_found}
      complexity when is_binary(complexity) ->
        with {:ok, normalized} <- string_to_existing_atom(complexity),
             true <- normalized in [:simple, :medium, :complex] do
          {:ok, normalized}
        else
          _ -> {:error, :invalid_value}
        end
      complexity when complexity in [:simple, :medium, :complex] ->
        {:ok, complexity}
      _ -> {:error, :invalid_value}
    end
  end

  # Private: PostgreSQL Settings KV store queries for models
  
  defp query_models_from_settings(provider, context) do
    # Build Settings key: "llm.providers.{provider}.models.{task_type}" or "llm.providers.{provider}.models"
    task_type = Map.get(context, :task_type)
    key = build_settings_key("llm.providers.#{provider}.models", task_type)
    
    case Settings.get(key) do
      nil -> {:error, :not_found}
      models when is_list(models) ->
        # Ensure all models are strings
        normalized = Enum.map(models, &to_string/1)
        {:ok, normalized}
      models when is_binary(models) ->
        # Try to parse as JSON array
        case Jason.decode(models) do
          {:ok, models_list} when is_list(models_list) ->
            normalized = Enum.map(models_list, &to_string/1)
            {:ok, normalized}
          _ -> {:error, :invalid_value}
        end
      _ -> {:error, :invalid_value}
    end
  end

  # Private: Helper to build Settings key with optional task_type suffix
  
  defp build_settings_key(base_key, nil), do: base_key
  defp build_settings_key(base_key, task_type) when is_atom(task_type) do
    "#{base_key}.#{task_type}"
  end
defp build_settings_key(base_key, task_type) when is_binary(task_type) do
  "#{base_key}.#{task_type}"
end
defp build_settings_key(base_key, _), do: base_key

defp string_to_existing_atom(value) when is_atom(value), do: {:ok, value}

defp string_to_existing_atom(value) when is_binary(value) do
  try do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> {:error, :invalid_atom}
  end
end

defp string_to_existing_atom(_), do: {:error, :invalid_atom}


# Private: Provider normalization and defaults

defp normalize_provider(provider) when is_atom(provider), do: Atom.to_string(provider)
  defp normalize_provider(provider) when is_binary(provider), do: String.downcase(provider)
  defp normalize_provider(other), do: inspect(other)

  defp get_default_models_for_provider(provider) do
    normalized = normalize_provider(provider)
    
    case normalized do
      provider when provider in ["claude", "claude_cli", "claude_http"] ->
        [
          "claude-3-5-sonnet-20241022",
          "claude-sonnet-4.5",
          "claude-3-5-haiku-20241022"
        ]
      
      provider when provider in ["gemini", "gemini_code_cli", "gemini_code_api", "gemini_cli", "gemini_http"] ->
        [
          "gemini-2.0-flash-exp",
          "gemini-1.5-flash"
        ]
      
      provider when provider in ["copilot", "github-copilot"] ->
        [
          "github-copilot",
          "gpt-5-codex"
        ]
      
      provider when provider in ["codex", "gpt-5-codex"] ->
        [
          "gpt-5-codex",
          "o3-mini-codex"
        ]
      
      _ ->
        # Default: return all available models
        [
          "claude-3-5-sonnet-20241022",
          "gemini-2.0-flash-exp",
          "gpt-5-codex"
        ]
    end
  end
end
