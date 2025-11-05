defmodule SingularityLLM.Providers.Mistral.BuildRequest do
  @moduledoc """
  Pipeline plug for building Mistral API requests.

  Mistral follows OpenAI-compatible format.
  """

  use SingularityLLM.Providers.OpenAICompatible.BuildRequest,
    provider: :mistral,
    base_url_env: "MISTRAL_API_BASE",
    default_base_url: "https://api.mistral.ai",
    api_key_env: "MISTRAL_API_KEY"
end
