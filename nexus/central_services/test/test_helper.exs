ExUnit.start()

# ======================================================================
# CENTRAL SERVICES TESTING FRAMEWORK - Mock infrastructure
# ======================================================================
#
# Provides mock implementations for CentralServices tests
# Uses pure Elixir modules (no Mox or third-party mocking libraries)

# ======================================================================
# MOCK MODULE: MockEmbeddingGenerator - Embedding service mock
# ======================================================================
# Simulates Singularity.EmbeddingGenerator for testing pattern aggregation.
# Used by: CentralCloud.Evolution.Patterns.Aggregator

defmodule MockEmbeddingGenerator do
  @moduledoc """
  Mock embedding generator simulating Singularity.EmbeddingGenerator.

  **Purpose**: Test pattern aggregation without requiring Singularity services.

  **Default Behavior**:
  - `embed/2` returns 2560-dimensional embedding
  - `dimension/1` returns 2560 (Qodo + Jina v3 concatenated)

  **Usage in Tests**:
      setup do
        Application.put_env(:central_services, :embedding_generator, MockEmbeddingGenerator)
        on_exit(fn -> Application.delete_env(:central_services, :embedding_generator) end)
        :ok
      end

  **Usage in Code**:
      defmodule CentralCloud.Evolution.Patterns.Aggregator do
        defp embedding_generator do
          Application.get_env(:central_services, :embedding_generator, Singularity.EmbeddingGenerator)
        end
        def generate_embedding(text) do
          embedding_generator().embed(text)
        end
      end

  **Functions Implemented**:
  - `embed(text, opts)` - Generate embedding for text (returns 2560-dim list)
  - `dimension(model)` - Get embedding dimension for a model
  """

  def embed(text, _opts \\ []) when is_binary(text) do
    # Return mock embedding with same dimension as production
    # Real EmbeddingGenerator returns Pgvector type, we use list for testing
    embedding = List.duplicate(0.1, 2560)
    {:ok, embedding}
  end

  def dimension(:combined), do: 2560
  def dimension(:qodo), do: 1536
  def dimension(:jina_v3), do: 1024
  def dimension(:minilm), do: 384
  def dimension(_), do: 2560
end

# ======================================================================
# TEST ENVIRONMENT CONFIGURATION
# ======================================================================

# Set flag so modules know they're running in test mode
Application.put_env(:central_services, :test_mode, true)
