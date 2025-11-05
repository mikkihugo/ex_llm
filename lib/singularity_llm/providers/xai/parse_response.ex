defmodule SingularityLLM.Providers.XAI.ParseResponse do
  @moduledoc """
  Pipeline plug for parsing XAI (Grok) API responses.

  XAI follows OpenAI-compatible response format.
  """

  use SingularityLLM.Providers.OpenAICompatible.ParseResponse,
    provider: :xai,
    cost_provider: "xai"
end
