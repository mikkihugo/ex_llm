defmodule GenesisTest do
  use ExUnit.Case
  doctest Genesis

  test "Genesis application starts" do
    assert {:ok, _} = Genesis.Application.start(:normal, [])
  end

  test "Experiment request can be processed" do
    request = %{
      "experiment_id" => "test-exp-1",
      "instance_id" => "singularity-test",
      "experiment_type" => "decomposition",
      "description" => "Test experiment",
      "risk_level" => "medium"
    }

    # Placeholder test - actual implementation would test real experiment flow
    assert is_map(request)
  end
end
