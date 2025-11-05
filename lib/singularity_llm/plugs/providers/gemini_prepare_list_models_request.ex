defmodule SingularityLLM.Plugs.Providers.GeminiPrepareListModelsRequest do
  @moduledoc """
  Prepares list models request for the Gemini API.

  Sets up the request path for retrieving available models.
  """

  use SingularityLLM.Plug

  @impl true
  def call(%SingularityLLM.Pipeline.Request{} = request, _opts) do
    # Gemini's models endpoint doesn't require a body
    request
    |> Map.put(:provider_request, %{})
    |> SingularityLLM.Pipeline.Request.assign(:http_method, :get)
    |> SingularityLLM.Pipeline.Request.assign(:http_path, "/models")
  end
end
