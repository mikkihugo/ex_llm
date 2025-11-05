defmodule SingularityLLM.Plugs.Providers.XAIListModelsHandler do
  @moduledoc """
  Handles list_models requests for XAI provider.

  Since XAI doesn't have a models API endpoint, this plug calls
  the provider's implementation which returns a static list.
  """

  alias SingularityLLM.Pipeline.Request

  @behaviour SingularityLLM.Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Request{} = request, _opts) do
    # Call the provider's list_models implementation
    case SingularityLLM.Providers.XAI.list_models() do
      {:ok, models} ->
        %{request | state: :completed, result: {:ok, models}}

      {:error, reason} ->
        error = %{
          type: :list_models_error,
          message: reason,
          provider: :xai
        }

        %{request | state: :error, errors: [error | request.errors]}
    end
  end
end
