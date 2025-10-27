defmodule Nexus.Providers.GeminiCode do
  @moduledoc """
  Gemini Code Assist provider for Nexus.

  Delegates to `ExLLM.Providers.GeminiCode` for the actual HTTP calls and token
  management.
  """

  require Logger

  alias ExLLM.Providers.GeminiCode, as: GeminiCodeProvider
  alias ExLLM.Providers.GeminiCode.TokenManager

  @default_model "models/gemini-2.5-pro"

  @doc """
  Execute a chat request using Gemini Code Assist.
  """
  @spec chat(list(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def chat(messages, opts \\ []) do
    case GeminiCodeProvider.chat(messages, opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        Logger.error("Gemini Code Assist request failed", reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Check whether Gemini Code Assist credentials are available.
  """
  @spec configured?() :: boolean()
  def configured? do
    GeminiCodeProvider.configured?()
  end

  @doc """
  Returns a default model identifier for Code Assist.
  """
  def default_model do
    default =
      case Application.get_env(:nexus, :gemini_code) do
        nil -> nil
        config when is_list(config) -> Keyword.get(config, :default_model)
        config when is_map(config) -> Map.get(config, :default_model)
        _ -> nil
      end

    default ||
      System.get_env("GEMINI_CODE_DEFAULT_MODEL") ||
      @default_model
  end

  @doc """
  Returns a list of models known to be supported by the Code Assist API.
  """
  def list_models do
    [
      %{
        id: "models/gemini-2.5-pro",
        name: "Gemini 2.5 Pro (Code Assist)",
        context_window: 200_000,
        capabilities: [:chat, :streaming, :code_generation, :analysis]
      },
      %{
        id: "models/gemini-2.5-flash",
        name: "Gemini 2.5 Flash (Code Assist)",
        context_window: 128_000,
        capabilities: [:chat, :code_generation]
      }
    ]
  end

  @doc """
  Exposes the raw token load helper (useful for diagnostics).
  """
  def ensure_tokens do
    TokenManager.ensure_tokens()
  end
end
