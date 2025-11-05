defmodule SingularityLLM.Plugs.Providers.OpenRouterPrepareListModelsRequest do
  @moduledoc """
  **DEPRECATED** - Use `SingularityLLM.Plugs.Providers.OpenAICompatiblePrepareListModelsRequest` instead.

  This module will be removed in v1.1.0. Please use the shared OpenAI-compatible
  implementation which provides the same functionality.
  """

  @deprecated "Use SingularityLLM.Plugs.Providers.OpenAICompatiblePrepareListModelsRequest instead"

  use SingularityLLM.Plug
  alias SingularityLLM.Plugs.Providers.OpenAICompatiblePrepareListModelsRequest

  @impl true
  defdelegate call(request, opts), to: OpenAICompatiblePrepareListModelsRequest
end
