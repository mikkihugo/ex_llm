defmodule SingularityLLM.Plugs.Providers.OllamaPrepareListModelsRequest do
  @moduledoc """
  Prepares list models request for the Ollama API.

  Sets up the request path for retrieving locally available models.
  """

  use SingularityLLM.Plug

  @impl true
  def call(%SingularityLLM.Pipeline.Request{} = request, _opts) do
    # Ollama's list endpoint shows locally available models
    request
    |> Map.put(:provider_request, %{})
    |> SingularityLLM.Pipeline.Request.assign(:http_method, :get)
    |> SingularityLLM.Pipeline.Request.assign(:http_path, "/api/tags")
  end
end
