defmodule SingularityLLM.Providers.OpenRouter.BuildRequest do
  @moduledoc """
  Pipeline plug for building OpenRouter API requests.

  OpenRouter follows OpenAI-compatible format but uses /api/v1 path.
  The Tesla BaseUrl middleware handles the /api prefix automatically.
  """

  use SingularityLLM.Providers.OpenAICompatible.BuildRequest,
    provider: :openrouter,
    base_url_env: "OPENROUTER_API_BASE",
    default_base_url: "https://openrouter.ai",
    api_key_env: "OPENROUTER_API_KEY"
end
