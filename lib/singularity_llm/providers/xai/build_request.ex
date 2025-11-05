defmodule SingularityLLM.Providers.XAI.BuildRequest do
  @moduledoc """
  Pipeline plug for building XAI (Grok) API requests.

  XAI follows OpenAI-compatible format.
  """

  use SingularityLLM.Providers.OpenAICompatible.BuildRequest,
    provider: :xai,
    base_url_env: "XAI_API_BASE",
    default_base_url: "https://api.x.ai",
    api_key_env: "XAI_API_KEY"
end
