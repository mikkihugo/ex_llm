# Serverless Embeddings Implementation

Replace GPU-dependent embeddings with API calls for cost optimization.

## Current (GPU-dependent)
```elixir
defmodule Singularity.Embeddings do
  def generate(text) do
    # Requires GPU + Python ML stack
    Bumblebee.load_model("microsoft/codebert-base")
    |> Bumblebee.embed(text)
  end
end
```

## New (Serverless API)
```elixir
defmodule Singularity.Embeddings do
  @openai_price_per_1k_tokens 0.0001  # $0.10 per 1M tokens

  def generate(text) do
    # No GPU required - pure API call
    case OpenAI.embeddings(text, model: "text-embedding-3-small") do
      {:ok, %{embeddings: embeddings, usage: %{total_tokens: tokens}}} ->
        cost = (tokens / 1000) * @openai_price_per_1k_tokens
        Logger.info("Embedding cost: $#\{:erlang.float_to_binary(cost, decimals: 6)\}")
        {:ok, embeddings}
      error -> error
    end
  end
end
```

## Configuration
```elixir
config :singularity, :embeddings,
  provider: :openai,  # or :huggingface, :together
  model: "text-embedding-3-small",
  api_key: System.get_env("OPENAI_API_KEY")
```

## Benefits
- ✅ **Zero GPU cost** - Pay per request
- ✅ **No ML ops** - API handles everything
- ✅ **Auto-scaling** - Handles traffic spikes
- ✅ **Simple deployment** - No Python/ML dependencies

## Cost Tracking
```elixir
defmodule Singularity.Embeddings.CostTracker do
  def track_usage(operation, tokens, cost) do
    # Store in PostgreSQL for monitoring
    Repo.insert(%EmbeddingUsage{
      operation: operation,
      tokens: tokens,
      cost_cents: cost * 100,
      timestamp: DateTime.utc_now()
    })
  end
end
```

## Switch Implementation

1. **Add API client** to `mix.exs`:
   ```elixir
   {:openai, "~> 0.1"}
   ```

2. **Update embedding calls** throughout codebase

3. **Remove Python ML dependencies** from flake.nix:
   ```nix
   includePython = false;  # No Python needed with APIs
   ```

4. **Test with mock API** first, then switch to real API

This reduces your infrastructure cost from ~$2,200/month to <$10/month for typical prototype usage!