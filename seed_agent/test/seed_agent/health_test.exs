defmodule SeedAgent.HealthTest do
  use ExUnit.Case, async: true

  alias SeedAgent.Health

  test "deep_health returns status map" do
    status = Health.deep_health()
    assert status.http_status == 200
    assert status.body.queue_depth == 0
    assert is_binary(status.body.system_time)
  end
end
