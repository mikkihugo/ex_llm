defmodule Nexus.CodexTokenStore do
  @moduledoc """
  PostgreSQL-backed token storage for Codex OAuth2.

  Stores OAuth tokens in the `oauth_tokens` table with automatic fallback
  to file storage if database is unavailable.

  ## Features

  - PostgreSQL storage with Ecto
  - Automatic token refresh when expired
  - Fallback to file storage (`~/.codex/tokens.json`)
  - Multi-instance safe (shared database)

  ## Usage

  Tokens are automatically managed by `Nexus.Providers.Codex`.
  """

  require Logger
  alias Nexus.OAuthToken

  @token_file Path.expand("~/.codex/tokens.json")

  @doc """
  Save OAuth tokens to database (with file fallback).
  """
  def save_tokens(tokens) do
    case OAuthToken.upsert("codex", tokens) do
      {:ok, _token} ->
        Logger.info("Codex tokens saved to database")
        :ok

      {:error, changeset} ->
        Logger.error("Failed to save to database: #{inspect(changeset.errors)}")
        save_to_file(tokens)
    end
  rescue
    error ->
      Logger.error("Database error: #{inspect(error)}")
      save_to_file(tokens)
  end

  @doc """
  Load OAuth tokens from database (with file fallback).
  """
  def load_tokens do
    case OAuthToken.get("codex") do
      {:ok, token} ->
        {:ok, token}

      {:error, :not_found} ->
        load_from_file()
    end
  rescue
    error ->
      Logger.error("Database error: #{inspect(error)}")
      load_from_file()
  end

  # File fallback functions

  defp save_to_file(tokens) do
    with :ok <- ensure_token_directory(),
         {:ok, json} <- Jason.encode(tokens, pretty: true),
         :ok <- File.write(@token_file, json),
         :ok <- set_permissions() do
      Logger.info("Codex tokens saved to file: #{@token_file}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to save tokens to file: #{inspect(reason)}")
        {:error, :save_failed}
    end
  end

  defp load_from_file do
    case File.read(@token_file) do
      {:ok, json} ->
        case Jason.decode(json, keys: :atoms) do
          {:ok, tokens} -> {:ok, struct(OAuthToken, tokens)}
          error -> error
        end

      {:error, :enoent} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  defp ensure_token_directory do
    @token_file |> Path.dirname() |> File.mkdir_p()
  end

  defp set_permissions do
    File.chmod(@token_file, 0o600)
  end
end
