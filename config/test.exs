import Config

# Configure SingularityLLM for testing using centralized configuration
#
# The centralized config provides consistent test settings across
# all test environments and helpers.

# Note: This is loaded early before the Testing.Config module is available,
# so we define minimal config here and let test_helper.exs apply the full config
config :singularity_llm,
  cache_strategy: SingularityLLM.Cache.Strategies.Test,
  env: :test
