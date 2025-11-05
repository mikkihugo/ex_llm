defmodule SingularityLLM.Cache do
  @moduledoc """
  Provides a caching layer for SingularityLLM operations.

  This module acts as a facade over different caching strategies. The strategy
  can be configured in your application's config files.

  ## Configuration

  In your `config/config.exs`, you can set the caching strategy:

      config :singularity_llm,
        cache_strategy: SingularityLLM.Cache.Strategies.Production

  For tests, you might want to use a different strategy:

      # config/test.exs
      config :singularity_llm,
        cache_strategy: SingularityLLM.Cache.Strategies.Test

  If no strategy is configured, it defaults to `SingularityLLM.Cache.Strategies.Production`.
  """

  @doc """
  Wraps a function execution with a caching layer.

  It uses the configured cache strategy to determine how to handle caching.
  See `SingularityLLM.Cache.Strategy.with_cache/3` for more details.
  """
  def with_cache(cache_key, opts, fun) do
    strategy().with_cache(cache_key, opts, fun)
  end

  defp strategy do
    Application.get_env(:singularity_llm, :cache_strategy, SingularityLLM.Cache.Strategies.Production)
  end
end
