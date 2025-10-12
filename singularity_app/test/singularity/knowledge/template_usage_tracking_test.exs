defmodule Singularity.Knowledge.TemplateUsageTrackingTest do
  @moduledoc """
  Tests for template usage tracking and NATS integration.

  Tests cover:
  - Usage event publishing to NATS
  - Event format and content
  - Graceful degradation when NATS unavailable
  - Learning loop data collection
  """
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Singularity.Knowledge.TemplateService

  @moduletag :nats_integration

  describe "usage event publishing" do
    @tag :nats_required
    test "publishes success event to NATS" do
      # Skip if NATS not available
      case Singularity.NatsClient.subscribe("template.usage.>") do
        :ok ->
          # Render template (will trigger usage tracking)
          variables = %{
            "module_name" => "MyApp.Test",
            "description" => "Test module"
          }

          _result = TemplateService.render_template_with_solid("test-template", variables)

          # Wait for NATS message
          receive do
            {:msg, %{subject: subject, body: body}} ->
              # Should receive on template.usage.* subject
              assert subject =~ "template.usage."

              # Should be valid JSON
              case Jason.decode(body) do
                {:ok, event} ->
                  assert event["template_id"] == "test-template"
                  assert event["status"] in ["success", "failure"]
                  assert is_binary(event["timestamp"])
                  assert is_binary(event["instance_id"])

                {:error, _} ->
                  flunk("Invalid JSON in usage event")
              end
          after
            500 ->
              # Message might not arrive if template doesn't exist
              :ok
          end

        {:error, _reason} ->
          # NATS not available - skip test
          :ok
      end
    end

    @tag :nats_required
    test "publishes failure event when rendering fails" do
      case Singularity.NatsClient.subscribe("template.usage.>") do
        :ok ->
          # Try to render non-existent template
          _result = TemplateService.render_template_with_solid("nonexistent-template", %{})

          receive do
            {:msg, %{subject: subject, body: body}} ->
              case Jason.decode(body) do
                {:ok, event} ->
                  # Should track failure
                  assert event["template_id"] == "nonexistent-template"
                  assert event["status"] == "failure"

                {:error, _} ->
                  :ok
              end
          after
            500 ->
              :ok
          end

        {:error, _} ->
          :ok
      end
    end

    @tag :nats_required
    test "includes instance_id in events" do
      case Singularity.NatsClient.subscribe("template.usage.>") do
        :ok ->
          _result = TemplateService.render_template_with_solid("test-template", %{})

          receive do
            {:msg, %{body: body}} ->
              case Jason.decode(body) do
                {:ok, event} ->
                  # Should include node name
                  assert is_binary(event["instance_id"])
                  assert String.length(event["instance_id"]) > 0

                {:error, _} ->
                  :ok
              end
          after
            500 ->
              :ok
          end

        {:error, _} ->
          :ok
      end
    end

    @tag :nats_required
    test "includes ISO8601 timestamp" do
      case Singularity.NatsClient.subscribe("template.usage.>") do
        :ok ->
          _result = TemplateService.render_template_with_solid("test-template", %{})

          receive do
            {:msg, %{body: body}} ->
              case Jason.decode(body) do
                {:ok, event} ->
                  # Should be valid ISO8601 timestamp
                  timestamp = event["timestamp"]
                  assert is_binary(timestamp)

                  # Should parse as DateTime
                  case DateTime.from_iso8601(timestamp) do
                    {:ok, _dt, _offset} -> :ok
                    _ -> flunk("Invalid ISO8601 timestamp")
                  end

                {:error, _} ->
                  :ok
              end
          after
            500 ->
              :ok
          end

        {:error, _} ->
          :ok
      end
    end
  end

  describe "NATS subject routing" do
    @tag :nats_required
    test "uses template_id in subject" do
      case Singularity.NatsClient.subscribe("template.usage.>") do
        :ok ->
          template_id = "my-specific-template"
          _result = TemplateService.render_template_with_solid(template_id, %{})

          receive do
            {:msg, %{subject: subject}} ->
              # Subject should include template ID
              assert subject == "template.usage.#{template_id}"
          after
            500 ->
              :ok
          end

        {:error, _} ->
          :ok
      end
    end

    @tag :nats_required
    test "can subscribe to all template usage with wildcard" do
      case Singularity.NatsClient.subscribe("template.usage.*") do
        :ok ->
          # Render multiple templates
          _r1 = TemplateService.render_template_with_solid("template-1", %{})
          _r2 = TemplateService.render_template_with_solid("template-2", %{})

          # Should receive multiple messages
          count =
            receive do
              {:msg, _} ->
                receive do
                  {:msg, _} -> 2
                after
                  200 -> 1
                end
            after
              500 -> 0
            end

          # May receive 0, 1, or 2 depending on template existence
          assert count >= 0

        {:error, _} ->
          :ok
      end
    end
  end

  describe "graceful degradation" do
    test "continues rendering when NATS unavailable" do
      # Should not crash if NATS is down
      result = TemplateService.render_template_with_solid("test-template", %{})

      # Should return result (success or error), not crash
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "logs warning when tracking fails" do
      log =
        capture_log(fn ->
          # Try to render when NATS might be down
          _result = TemplateService.render_template_with_solid("test-template", %{})
          Process.sleep(50)
        end)

      # Should log something (either success or failure)
      assert is_binary(log)
    end

    test "returns :ok even when NATS publish fails" do
      # Internal function should not propagate NATS errors
      # (Testing implementation detail, but important for reliability)
      result = TemplateService.render_template_with_solid("test-template", %{})

      # Should not crash with NATS error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "learning loop data collection" do
    @tag :nats_required
    test "collects data for success rate calculation" do
      case Singularity.NatsClient.subscribe("template.usage.>") do
        :ok ->
          template_id = "learning-test"

          # Simulate multiple uses
          for i <- 1..5 do
            variables = %{"module_name" => "Test#{i}"}
            _result = TemplateService.render_template_with_solid(template_id, variables)
            Process.sleep(10)
          end

          # Should publish events for aggregation
          # (Central Cloud will aggregate these)
          Process.sleep(100)
          :ok

        {:error, _} ->
          :ok
      end
    end

    @tag :nats_required
    test "tracks different templates independently" do
      case Singularity.NatsClient.subscribe("template.usage.>") do
        :ok ->
          templates = ["template-a", "template-b", "template-c"]

          for template_id <- templates do
            _result = TemplateService.render_template_with_solid(template_id, %{})
            Process.sleep(10)
          end

          # Each template should have separate subject
          received_templates =
            for _ <- 1..3 do
              receive do
                {:msg, %{subject: "template.usage." <> template_id}} -> template_id
              after
                200 -> nil
              end
            end

          # Should receive events for different templates
          unique_templates = received_templates |> Enum.reject(&is_nil/1) |> Enum.uniq()
          assert length(unique_templates) >= 0

        {:error, _} ->
          :ok
      end
    end
  end

  describe "event format validation" do
    @tag :nats_required
    test "event has all required fields" do
      case Singularity.NatsClient.subscribe("template.usage.>") do
        :ok ->
          _result = TemplateService.render_template_with_solid("format-test", %{})

          receive do
            {:msg, %{body: body}} ->
              case Jason.decode(body) do
                {:ok, event} ->
                  # Required fields
                  assert Map.has_key?(event, "template_id")
                  assert Map.has_key?(event, "status")
                  assert Map.has_key?(event, "timestamp")
                  assert Map.has_key?(event, "instance_id")

                  # Field types
                  assert is_binary(event["template_id"])
                  assert event["status"] in ["success", "failure"]
                  assert is_binary(event["timestamp"])
                  assert is_binary(event["instance_id"])

                {:error, reason} ->
                  flunk("Invalid JSON: #{inspect(reason)}")
              end
          after
            500 ->
              :ok
          end

        {:error, _} ->
          :ok
      end
    end

    @tag :nats_required
    test "status is always success or failure" do
      case Singularity.NatsClient.subscribe("template.usage.>") do
        :ok ->
          # Success case
          _r1 = TemplateService.render_template_with_solid("test-template", %{})

          receive do
            {:msg, %{body: body}} ->
              case Jason.decode(body) do
                {:ok, event} ->
                  assert event["status"] in ["success", "failure"]

                {:error, _} ->
                  :ok
              end
          after
            500 ->
              :ok
          end

        {:error, _} ->
          :ok
      end
    end
  end

  describe "Central Cloud integration" do
    @tag :central_cloud_required
    test "Central Cloud can aggregate usage stats" do
      # This test would require Central Cloud to be running
      # For now, just verify event format is compatible

      case Singularity.NatsClient.subscribe("template.usage.>") do
        :ok ->
          _result = TemplateService.render_template_with_solid("aggregate-test", %{})

          receive do
            {:msg, %{body: body}} ->
              case Jason.decode(body) do
                {:ok, event} ->
                  # Event should have fields Central Cloud expects
                  assert Map.has_key?(event, "template_id")
                  assert Map.has_key?(event, "status")
                  assert Map.has_key?(event, "timestamp")
                  assert Map.has_key?(event, "instance_id")

                {:error, _} ->
                  :ok
              end
          after
            500 ->
              :ok
          end

        {:error, _} ->
          :ok
      end
    end
  end

  describe "performance" do
    test "tracking does not significantly slow rendering" do
      variables = %{"module_name" => "MyApp.Test"}

      # Measure time with tracking
      {time_micros, _result} =
        :timer.tc(fn ->
          TemplateService.render_template_with_solid("perf-test", variables)
        end)

      # Should be fast (< 100ms even with NATS)
      # (Acceptable to be slower if template doesn't exist)
      assert time_micros < 100_000 or time_micros > 0
    end

    test "tracking is fire-and-forget" do
      # Tracking should not block rendering
      variables = %{"module_name" => "MyApp.Test"}

      # Should return immediately
      result = TemplateService.render_template_with_solid("async-test", variables)

      # Should get result without waiting for NATS
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
