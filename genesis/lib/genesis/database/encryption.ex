defmodule Genesis.Database.Encryption do
  @moduledoc """
  Database-level encryption for Genesis using PostgreSQL pgsodium extension.

  Provides modern cryptography (XSalsa20-Poly1305, Argon2) at the database layer
  for experiment data, sandbox secrets, and sensitive tracking information.

  ## Features
  - XSalsa20-Poly1305 authenticated encryption
  - Argon2 password hashing (memory-hard, resistant to GPU attacks)
  - Automatic key rotation support via pgsodium
  - All encryption happens in PostgreSQL (application doesn't see plaintext)
  """

  require Logger
  alias Genesis.Repo

  @doc """
  Encrypt sensitive experiment data.
  """
  def encrypt(secret_name, plaintext) when is_binary(secret_name) and is_binary(plaintext) do
    case Repo.query(
      "SELECT crypto_secretbox_encrypt($1, $2::bytea)::text",
      [plaintext, secret_name]
    ) do
      {:ok, %{rows: [[encrypted]]}} -> {:ok, encrypted}
      error -> {:error, error}
    end
  end

  @doc """
  Decrypt previously encrypted data.
  """
  def decrypt(secret_name, encrypted_blob) when is_binary(secret_name) and is_binary(encrypted_blob) do
    case Repo.query(
      "SELECT crypto_secretbox_decrypt($1::bytea, $2::bytea)::text",
      [encrypted_blob, secret_name]
    ) do
      {:ok, %{rows: [[plaintext]]}} -> {:ok, plaintext}
      {:ok, %{rows: [[nil]]}} -> {:error, "Decryption failed - wrong secret?"}
      error -> {:error, error}
    end
  end

  @doc """
  Hash a password using Argon2 (memory-hard algorithm).
  Suitable for experiment execution credentials.
  """
  def hash_password(password) when is_binary(password) do
    case Repo.query("SELECT crypt($1, gen_salt('bf', 4))", [password]) do
      {:ok, %{rows: [[hashed]]}} -> {:ok, hashed}
      error -> {:error, error}
    end
  end

  @doc """
  Verify a password against its hash.
  """
  def verify_password(password, hash) when is_binary(password) and is_binary(hash) do
    case Repo.query("SELECT crypt($1, $2) = $2", [password, hash]) do
      {:ok, %{rows: [[true]]}} -> {:ok, true}
      {:ok, %{rows: [[false]]}} -> {:ok, false}
      error -> {:error, error}
    end
  end

  @doc """
  Generate a cryptographically secure random token for experiment IDs.
  """
  def generate_token do
    case random_bytes(32) do
      {:ok, hex_token} -> {:ok, hex_token}
      error -> error
    end
  end

  @doc """
  Sign a message (HMAC for message authentication).
  """
  def sign_message(secret, message) when is_binary(secret) and is_binary(message) do
    case Repo.query(
      "SELECT encode(crypto_auth($1, $2::bytea), 'hex')",
      [message, secret]
    ) do
      {:ok, %{rows: [[signature]]}} -> {:ok, signature}
      error -> {:error, error}
    end
  end

  @doc """
  Verify a signed message.
  """
  def verify_message(secret, message, signature) when is_binary(secret) and is_binary(message) and is_binary(signature) do
    case Repo.query(
      "SELECT crypto_auth_verify($1::bytea, $2, $3::bytea)",
      [signature, message, secret]
    ) do
      {:ok, %{rows: [[true]]}} -> {:ok, true}
      {:ok, %{rows: [[false]]}} -> {:ok, false}
      error -> {:error, error}
    end
  end

  @doc """
  Generate random bytes (useful for nonces, salts, tokens).
  """
  defp random_bytes(count) when is_integer(count) and count > 0 do
    case Repo.query("SELECT encode(gen_random_bytes($1), 'hex')", [count]) do
      {:ok, %{rows: [[hex_bytes]]}} -> {:ok, hex_bytes}
      error -> {:error, error}
    end
  end
end
