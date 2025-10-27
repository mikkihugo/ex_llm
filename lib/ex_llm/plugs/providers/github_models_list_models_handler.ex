defmodule ExLLM.Plugs.Providers.GitHubModelsListModelsHandler do
  @moduledoc """
  Plug that handles listing models for GitHub Models provider.
  
  Calls the provider's list_models function directly and formats the response.
  """

  use ExLLM.Plug

  @impl true
  def call(%ExLLM.Pipeline.Request{} = request, _opts) do
    case ExLLM.Providers.GitHubModels.list_models() do
      {:ok, models} ->
        # Add provider information to each model
        models_with_provider = Enum.map(models, &Map.put(&1, :provider, :github_models))
        
        request
        |> Map.put(:result, {:ok, models_with_provider})
        |> ExLLM.Pipeline.Request.put_state(:completed)

      {:error, reason} ->
        ExLLM.Pipeline.Request.halt_with_error(request, %{
          error: reason,
          plug: __MODULE__,
          github_models_handler_called: true
        })
    end
  end
end