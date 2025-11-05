defmodule SingularityLLM.Plugs.Providers.PerplexityPrepareListModelsRequest do
  @moduledoc """
  Prepares list models request for Perplexity API.

  Perplexity uses the /models endpoint without the /v1 prefix.
  """

  use SingularityLLM.Plug

  @impl true
  def call(%SingularityLLM.Pipeline.Request{} = request, _opts) do
    request
    |> Map.put(:provider_request, %{})
    |> SingularityLLM.Pipeline.Request.assign(:http_method, :get)
    # No /v1 prefix
    |> SingularityLLM.Pipeline.Request.assign(:http_path, "/models")
  end
end
