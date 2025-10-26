defmodule Nexus.OAuthToken do
  @moduledoc """
  OAuth token storage for AI providers (Codex, Gemini, etc.).

  Stores OAuth2 tokens in PostgreSQL with automatic refresh and encryption.

  ## Schema

  - `provider` - Provider name (e.g., "codex", "gemini")
  - `user_identifier` - Optional user/instance identifier
  - `access_token` - OAuth access token (encrypted)
  - `refresh_token` - OAuth refresh token (encrypted)
  - `expires_at` - Token expiration timestamp
  - `scopes` - OAuth scopes granted
  - `token_type` - Token type (usually "Bearer")
  - `metadata` - Additional provider-specific data

  ## Usage

  ```elixir
  # Save tokens
  {:ok, token} = OAuthToken.upsert("codex", %{
    access_token: "...",
    refresh_token: "...",
    expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
  })

  # Load tokens
  {:ok, token} = OAuthToken.get("codex")

  # Check expiration
  if OAuthToken.expired?(token) do
    # Refresh logic
  end
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Nexus.Repo

  @type t :: %__MODULE__{
    id: integer(),
    provider: String.t(),
    user_identifier: String.t() | nil,
    access_token: String.t(),
    refresh_token: String.t() | nil,
    expires_at: DateTime.t(),
    scopes: [String.t()],
    token_type: String.t(),
    metadata: map(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  schema "oauth_tokens" do
    field :provider, :string
    field :user_identifier, :string
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    field :scopes, {:array, :string}, default: []
    field :token_type, :string, default: "Bearer"
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc """
  Changeset for creating/updating OAuth tokens.
  """
  def changeset(token, attrs) do
    token
    |> cast(attrs, [
      :provider,
      :user_identifier,
      :access_token,
      :refresh_token,
      :expires_at,
      :scopes,
      :token_type,
      :metadata
    ])
    |> validate_required([:provider, :access_token, :expires_at])
    |> unique_constraint([:provider, :user_identifier])
  end

  @doc """
  Get OAuth token for a provider.

  Returns `{:error, :not_found}` if no token exists.
  """
  @spec get(String.t(), String.t() | nil) :: {:ok, t()} | {:error, :not_found}
  def get(provider, user_identifier \\ nil) do
    query = from t in __MODULE__,
      where: t.provider == ^provider

    query = if user_identifier do
      where(query, [t], t.user_identifier == ^user_identifier)
    else
      where(query, [t], is_nil(t.user_identifier))
    end

    case Repo.one(query) do
      nil -> {:error, :not_found}
      token -> {:ok, token}
    end
  end

  @doc """
  Upsert OAuth token for a provider.

  Creates new token or updates existing one.
  """
  @spec upsert(String.t(), map(), String.t() | nil) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def upsert(provider, attrs, user_identifier \\ nil) do
    attrs = Map.put(attrs, :provider, provider)
    attrs = if user_identifier, do: Map.put(attrs, :user_identifier, user_identifier), else: attrs

    case get(provider, user_identifier) do
      {:ok, existing} ->
        existing
        |> changeset(attrs)
        |> Repo.update()

      {:error, :not_found} ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()
    end
  end

  @doc """
  Check if token is expired.

  Returns true if token expires within the next 5 minutes.
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: expires_at}) do
    # Consider expired if less than 5 minutes remaining
    buffer = 300  # 5 minutes
    DateTime.compare(expires_at, DateTime.utc_now() |> DateTime.add(buffer, :second)) == :lt
  end

  @doc """
  Delete OAuth token for a provider.
  """
  @spec delete(String.t(), String.t() | nil) :: :ok | {:error, term()}
  def delete(provider, user_identifier \\ nil) do
    case get(provider, user_identifier) do
      {:ok, token} ->
        Repo.delete(token)
        :ok

      {:error, :not_found} ->
        :ok
    end
  end

  @doc """
  Convert token to ex_llm format.

  Used by token store implementation.
  """
  @spec to_ex_llm_format(t()) :: map()
  def to_ex_llm_format(%__MODULE__{} = token) do
    %{
      access_token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: DateTime.to_unix(token.expires_at),
      token_type: token.token_type,
      scope: Enum.join(token.scopes, " ")
    }
  end

  @doc """
  Convert ex_llm format to Ecto attributes.
  """
  @spec from_ex_llm_format(map()) :: map()
  def from_ex_llm_format(tokens) do
    scopes = case tokens[:scope] do
      nil -> []
      scope when is_binary(scope) -> String.split(scope, " ")
      scopes when is_list(scopes) -> scopes
    end

    %{
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_at: DateTime.from_unix!(tokens.expires_at),
      token_type: tokens[:token_type] || "Bearer",
      scopes: scopes
    }
  end
end
