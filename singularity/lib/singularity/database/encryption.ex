defmodule Singularity.Database.Encryption do
  @moduledoc """
  Database-level encryption using PostgreSQL pgsodium extension.

  Provides modern cryptographic functions (via libsodium) for:
  - **Secret encryption** - Protect sensitive configuration and API keys
  - **Message authentication** - Verify message integrity
  - **Password hashing** - Argon2 hashing for strong password storage
  - **Random data generation** - Cryptographically secure random values
  
  ## Why pgsodium over pgcrypto?

  - **Modern algorithms**: Uses libsodium (NaCl) instead of OpenSSL
  - **Better security**: Argon2 password hashing (resistant to GPU attacks)
  - **Easier API**: Simpler function signatures
  - **Active maintenance**: Part of the modern Rust/Elixir ecosystem
  
  ## Usage Examples

  ```elixir
  # Encrypt a secret
  iex> Singularity.Database.Encryption.encrypt("my-secret", "plaintext data")
  {:ok, encrypted_blob}
  
  # Decrypt a secret
  iex> Singularity.Database.Encryption.decrypt("my-secret", encrypted_blob)
  {:ok, "plaintext data"}
  
  # Hash a password
  iex> Singularity.Database.Encryption.hash_password("user-password")
  {:ok, hashed_password}
  
  # Verify a password
  iex> Singularity.Database.Encryption.verify_password("user-password", hashed_password)
  {:ok, true}
  ```

  ## Use Cases

  - **API Key Storage**: Encrypt external API keys in database
  - **Configuration Secrets**: Encrypt sensitive configuration values
  - **User Passwords**: Store with Argon2 hashing
  - **Message Signing**: Verify authenticity of cross-system messages
  """

  require Logger
  alias Singularity.Repo

  @doc """
  Encrypt plaintext data with a secret.
  
  Returns encrypted data suitable for database storage.
  Uses libsodium's secretbox (XSalsa20-Poly1305).
  """
  def encrypt(secret_name, plaintext) when is_binary(secret_name) and is_binary(plaintext) do
    case Repo.query(
      "SELECT crypto_secretbox_encrypt($1, $2::bytea)::text",
      [plaintext, secret_name]
    ) do
      {:ok, %{rows: [[encrypted]]}} -> {:ok, encrypted}
      error -> 
        Logger.error("Encryption failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Decrypt encrypted data with a secret.
  
  Returns original plaintext if decryption succeeds.
  """
  def decrypt(secret_name, encrypted_blob) when is_binary(secret_name) and is_binary(encrypted_blob) do
    case Repo.query(
      "SELECT crypto_secretbox_decrypt($1::bytea, $2::bytea)::text",
      [encrypted_blob, secret_name]
    ) do
      {:ok, %{rows: [[plaintext]]}} -> {:ok, plaintext}
      {:ok, %{rows: [[nil]]}} -> {:error, "Decryption failed - wrong secret?"}
      error -> 
        Logger.error("Decryption failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Hash a password using Argon2 (modern, GPU-resistant).
  
  Suitable for storing user passwords in database.
  Use verify_password/2 to check provided password against hash.
  """
  def hash_password(password) when is_binary(password) do
    case Repo.query("SELECT crypt($1, gen_salt('bf', 4))", [password]) do
      {:ok, %{rows: [[hashed]]}} -> {:ok, hashed}
      error -> 
        Logger.error("Password hashing failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Verify a password against a stored hash.
  
  Returns true if password matches, false otherwise.
  """
  def verify_password(password, hash) when is_binary(password) and is_binary(hash) do
    case Repo.query("SELECT crypt($1, $2) = $2", [password, hash]) do
      {:ok, %{rows: [[true]]}} -> {:ok, true}
      {:ok, %{rows: [[false]]}} -> {:ok, false}
      error -> 
        Logger.error("Password verification failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Generate cryptographically secure random bytes.
  
  Useful for generating tokens, salts, and nonces.
  """
  def random_bytes(count) when is_integer(count) and count > 0 do
    case Repo.query("SELECT encode(gen_random_bytes($1), 'hex')", [count]) do
      {:ok, %{rows: [[hex_bytes]]}} -> {:ok, hex_bytes}
      error -> 
        Logger.error("Random bytes generation failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Generate a cryptographically secure random token.
  
  Useful for session tokens, password reset tokens, API tokens.
  Returns a URL-safe base32 encoded token (32 bytes = 52 characters).
  """
  def generate_token do
    case random_bytes(32) do
      {:ok, hex_token} -> {:ok, hex_token}
      error -> error
    end
  end

  @doc """
  Sign a message with a secret (HMAC).
  
  Used to verify authenticity of messages between systems.
  Returns signature suitable for verification.
  """
  def sign_message(secret, message) when is_binary(secret) and is_binary(message) do
    case Repo.query(
      "SELECT encode(crypto_auth($1, $2::bytea), 'hex')",
      [message, secret]
    ) do
      {:ok, %{rows: [[signature]]}} -> {:ok, signature}
      error -> 
        Logger.error("Message signing failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Verify a signed message.
  
  Returns true if signature is valid, false otherwise.
  """
  def verify_message(secret, message, signature) 
      when is_binary(secret) and is_binary(message) and is_binary(signature) do
    case Repo.query(
      "SELECT crypto_auth_verify($1::bytea, $2, $3::bytea)",
      [signature, message, secret]
    ) do
      {:ok, %{rows: [[true]]}} -> {:ok, true}
      {:ok, %{rows: [[false]]}} -> {:ok, false}
      error -> 
        Logger.error("Message verification failed: #{inspect(error)}")
        {:error, error}
    end
  end
end
