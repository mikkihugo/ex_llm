defmodule SingularityLLM.Providers.Mistral.ParseResponse do
  @moduledoc """
  Pipeline plug for parsing Mistral API responses.

  Mistral follows OpenAI-compatible response format.
  """

  use SingularityLLM.Providers.OpenAICompatible.ParseResponse,
    provider: :mistral,
    cost_provider: "mistral"
end
