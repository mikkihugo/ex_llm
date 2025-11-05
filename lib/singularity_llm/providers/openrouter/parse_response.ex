defmodule SingularityLLM.Providers.OpenRouter.ParseResponse do
  @moduledoc """
  Pipeline plug for parsing OpenRouter API responses.

  OpenRouter follows OpenAI-compatible response format.
  """

  use SingularityLLM.Providers.OpenAICompatible.ParseResponse,
    provider: :openrouter,
    cost_provider: "openrouter"
end
