defmodule Nexus.Providers.Codex.ConfigLoader do
  @moduledoc """
  Loads Codex configuration from ~/.codex directory.
  
  This module reads the actual OAuth tokens and configuration
  from the user's local Codex installation.
  """
  
  require Logger
  
  @codex_dir Path.expand("~/.codex")
  @auth_file Path.join(@codex_dir, "auth.json")
  @tokens_file Path.join(@codex_dir, "tokens.json")
  @config_file Path.join(@codex_dir, "config.toml")
  
  @doc """
  Load OAuth tokens from ~/.codex/auth.json
  """
  def load_auth_tokens do
    case File.read(@auth_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:json_decode, reason}}
        end
      {:error, reason} -> {:error, {:file_read, reason}}
    end
  end
  
  @doc """
  Load tokens from ~/.codex/tokens.json
  """
  def load_tokens do
    case File.read(@tokens_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:json_decode, reason}}
        end
      {:error, reason} -> {:error, {:file_read, reason}}
    end
  end
  
  @doc """
  Load configuration from ~/.codex/config.toml
  """
  def load_config do
    case File.read(@config_file) do
      {:ok, content} ->
        case Toml.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:toml_decode, reason}}
        end
      {:error, reason} -> {:error, {:file_read, reason}}
    end
  end
  
  @doc """
  Get the configured model from config.toml
  """
  def get_configured_model do
    case load_config() do
      {:ok, config} -> 
        model = config["model"] || "gpt-5-codex"
        {:ok, model}
      {:error, reason} -> 
        Logger.warning("Failed to load Codex config: #{inspect(reason)}")
        {:ok, "gpt-5-codex"}  # fallback
    end
  end
  
  @doc """
  Get the reasoning effort level from config.toml
  """
  def get_reasoning_effort do
    case load_config() do
      {:ok, config} -> 
        effort = config["model_reasoning_effort"] || "medium"
        {:ok, effort}
      {:error, reason} -> 
        Logger.warning("Failed to load Codex config: #{inspect(reason)}")
        {:ok, "medium"}  # fallback
    end
  end
  
  @doc """
  Check if Codex is properly configured with valid tokens
  """
  def configured? do
    case load_auth_tokens() do
      {:ok, %{"tokens" => %{"access_token" => token}}} when is_binary(token) and byte_size(token) > 10 ->
        true
      _ ->
        false
    end
  end
end
