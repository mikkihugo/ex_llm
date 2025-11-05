defmodule SingularityLLM.Builder do
  @moduledoc """
  **DEPRECATED** - Use `SingularityLLM.ChatBuilder` instead.

  This module is deprecated and will be removed in a future version.
  Please use `SingularityLLM.ChatBuilder` directly which provides the same functionality.

  ## Migration Guide

      # OLD (deprecated)
      {:ok, response} = 
        SingularityLLM.Builder.build(:openai, messages)
        |> SingularityLLM.Builder.with_model("gpt-4")
        |> SingularityLLM.Builder.execute()

      # NEW (recommended)
      {:ok, response} = 
        SingularityLLM.ChatBuilder.new(:openai, messages)
        |> SingularityLLM.ChatBuilder.with_model("gpt-4")
        |> SingularityLLM.ChatBuilder.execute()
  """

  @deprecated "Use SingularityLLM.ChatBuilder instead. This module will be removed in v1.1.0"

  alias SingularityLLM.ChatBuilder

  # Core functions with deprecation warnings
  defdelegate build(provider, messages), to: ChatBuilder, as: :new

  defdelegate with_model(builder, model), to: ChatBuilder

  defdelegate with_temperature(builder, temperature), to: ChatBuilder

  defdelegate with_max_tokens(builder, max_tokens), to: ChatBuilder

  defdelegate with_plug(builder, plug, opts \\ []), to: ChatBuilder, as: :with_custom_plug

  defdelegate execute(builder), to: ChatBuilder

  defdelegate stream(builder, callback), to: ChatBuilder

  defdelegate with_cache(builder, opts \\ []), to: ChatBuilder

  defdelegate without_cache(builder), to: ChatBuilder

  @deprecated "Use SingularityLLM.ChatBuilder.without_cost_tracking/1 instead"
  defdelegate without_cost_tracking(builder), to: ChatBuilder

  @deprecated "Use SingularityLLM.ChatBuilder.with_custom_plug/3 instead"
  defdelegate with_custom_plug(builder, plug, opts \\ []), to: ChatBuilder

  @deprecated "Use SingularityLLM.ChatBuilder.with_context_strategy/3 instead"
  defdelegate with_context_strategy(builder, strategy, opts \\ []), to: ChatBuilder

  @deprecated "Use SingularityLLM.ChatBuilder.inspect_pipeline/1 instead"
  defdelegate inspect_pipeline(builder), to: ChatBuilder

  @deprecated "Use SingularityLLM.ChatBuilder.debug_info/1 instead"
  defdelegate debug_info(builder), to: ChatBuilder
end
