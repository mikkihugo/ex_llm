defmodule SingularityLLM.APIIntegrationTest do
  use ExUnit.Case
  doctest SingularityLLM

  @moduletag :integration

  test "supported_providers includes anthropic" do
    assert :anthropic in SingularityLLM.supported_providers()
  end

  test "supported_providers includes xai" do
    assert :xai in SingularityLLM.supported_providers()
  end

  test "can get default model for anthropic" do
    model = SingularityLLM.default_model(:anthropic)
    assert is_binary(model)
  end

  test "configured? returns boolean for anthropic" do
    result = SingularityLLM.configured?(:anthropic)
    assert is_boolean(result)
  end

  test "list_models returns ok tuple for anthropic" do
    assert {:ok, models} = SingularityLLM.list_models(:anthropic)
    assert is_list(models)
  end

  test "can get default model for xai" do
    model = SingularityLLM.default_model(:xai)
    assert is_binary(model)
    assert model == "grok-3"
  end

  test "configured? returns boolean for xai" do
    result = SingularityLLM.configured?(:xai)
    assert is_boolean(result)
  end

  test "list_models returns ok tuple for xai" do
    assert {:ok, models} = SingularityLLM.list_models(:xai)
    assert is_list(models)
    assert length(models) > 0
  end
end
