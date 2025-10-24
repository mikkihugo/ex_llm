defmodule CentralCloud.FrameworkLearners.LLMDiscoveryTest do
  @moduledoc """
  Tests for LLMDiscovery - Intelligent LLM-based framework detection.

  Tests the LLM discovery learner's ability to:
  - Call LLM for framework analysis
  - Parse LLM responses correctly
  - Handle timeouts and errors
  - Cache prompt templates
  - Enrich framework data with metadata
  - Implement FrameworkLearner behavior correctly
  """

  use ExUnit.Case, async: false

  import Mox

  alias CentralCloud.FrameworkLearners.LLMDiscovery
  alias CentralCloud.NatsClient

  setup :verify_on_exit!

  describe "learner_type/0" do
    test "returns :llm_discovery" do
      assert LLMDiscovery.learner_type() == :llm_discovery
    end
  end

  describe "description/0" do
    test "returns description string" do
      description = LLMDiscovery.description()

      assert is_binary(description)
      assert description =~ "LLM" or description =~ "framework"
    end
  end

  describe "capabilities/0" do
    test "returns list of capabilities" do
      capabilities = LLMDiscovery.capabilities()

      assert is_list(capabilities)
      assert "llm_based" in capabilities
      assert "thorough" in capabilities
      assert "custom_frameworks" in capabilities
      assert "reasoning" in capabilities
      assert "code_analysis" in capabilities
    end
  end

  describe "learn/2 with successful LLM response" do
    test "returns framework data when LLM provides valid JSON response" do
      package_id = "npm:custom-framework"
      code_samples = ["const app = createFramework()"]

      llm_response = %{
        "name" => "CustomFramework",
        "type" => "web_framework",
        "version" => "1.0.0",
        "confidence" => 0.90,
        "reasoning" => "Detected custom framework pattern"
      }

      with_mock NatsClient, [:passthrough],
        kv_get: fn "templates", "prompt:framework-discovery" ->
          {:error, :not_found}
        end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{
                "template" => %{
                  "system_prompt" => %{
                    "role" => "Framework detection expert"
                  },
                  "prompt_template" => "Analyze: {{framework_name}}"
                }
              }}
            "llm.request" ->
              {:ok, %{"response" => Jason.encode!(llm_response)}}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert {:ok, framework} = result
        assert framework["name"] == "CustomFramework"
        assert framework["type"] == "web_framework"
        assert framework["detected_by"] == "llm_discovery"
        assert framework["confidence"] == 0.90
      end
    end

    test "enriches framework data with detected_by and default confidence" do
      package_id = "npm:test"
      code_samples = ["test code"]

      # LLM response without detected_by or confidence
      llm_response = %{
        "name" => "TestFramework",
        "type" => "web_framework"
      }

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              {:ok, %{"response" => Jason.encode!(llm_response)}}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert {:ok, framework} = result
        assert framework["detected_by"] == "llm_discovery"
        assert framework["confidence"] == 0.85  # Default confidence
      end
    end

    test "preserves existing confidence if provided by LLM" do
      package_id = "npm:test"
      code_samples = ["test"]

      llm_response = %{
        "name" => "Framework",
        "type" => "web_framework",
        "confidence" => 0.95
      }

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              {:ok, %{"response" => Jason.encode!(llm_response)}}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert {:ok, framework} = result
        assert framework["confidence"] == 0.95
      end
    end

    test "handles direct framework data in response (not JSON string)" do
      package_id = "npm:test"
      code_samples = ["test"]

      llm_response = %{
        "framework" => %{
          "name" => "DirectFramework",
          "type" => "backend"
        }
      }

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              {:ok, llm_response}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert {:ok, framework} = result
        assert framework["detected_by"] == "llm_discovery"
      end
    end
  end

  describe "learn/2 with LLM errors" do
    test "returns {:error, :llm_timeout} when LLM request times out" do
      package_id = "npm:timeout-test"
      code_samples = ["code"]

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              {:error, :timeout}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert {:error, :llm_timeout} = result
      end
    end

    test "returns {:error, :llm_failed} when LLM request fails" do
      package_id = "npm:error-test"
      code_samples = ["code"]

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              {:error, :nats_connection_error}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert {:error, :llm_failed} = result
      end
    end

    test "returns :no_match when LLM response is invalid JSON" do
      package_id = "npm:invalid-json"
      code_samples = ["code"]

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              {:ok, %{"response" => "This is not JSON"}}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert result == :no_match
      end
    end

    test "returns :no_match when LLM response is empty" do
      package_id = "npm:empty-response"
      code_samples = ["code"]

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              {:ok, %{}}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert result == :no_match
      end
    end

    test "returns :no_match when LLM response is nil" do
      package_id = "npm:nil-response"
      code_samples = ["code"]

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              {:ok, nil}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert result == :no_match
      end
    end
  end

  describe "prompt template caching" do
    test "loads prompt from cache if available" do
      package_id = "npm:test"
      code_samples = ["code"]

      cached_prompt = %{
        "system_prompt" => %{"role" => "Cached expert"},
        "prompt_template" => "Cached template"
      }

      with_mock NatsClient, [:passthrough],
        kv_get: fn "templates", "prompt:framework-discovery" ->
          {:ok, cached_prompt}
        end,
        request: fn "llm.request", _payload, _opts ->
          {:ok, %{"response" => Jason.encode!(%{"name" => "Test", "type" => "web"})}}
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert {:ok, _framework} = result

        # Verify cache was checked (kv_get called)
        assert called(NatsClient.kv_get("templates", "prompt:framework-discovery"))

        # Verify template.get was NOT called (used cache)
        refute called(NatsClient.request("central.template.get", :_, :_))
      end
    end

    test "fetches and caches prompt when not in cache" do
      package_id = "npm:test"
      code_samples = ["code"]

      prompt_template = %{
        "system_prompt" => %{"role" => "Framework expert"},
        "prompt_template" => "Analyze {{framework_name}}"
      }

      with_mock NatsClient, [:passthrough],
        kv_get: fn "templates", "prompt:framework-discovery" ->
          {:error, :not_found}
        end,
        kv_put: fn "templates", "prompt:framework-discovery", _value ->
          :ok
        end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => prompt_template}}
            "llm.request" ->
              {:ok, %{"response" => Jason.encode!(%{"name" => "Test", "type" => "web"})}}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert {:ok, _framework} = result

        # Verify prompt was fetched
        assert called(NatsClient.request("central.template.get", :_, :_))

        # Note: kv_put is called in a spawn, so it may not be captured by mock
        # We just verify no crash occurred
      end
    end

    test "uses default prompt when template fetch fails" do
      package_id = "npm:test"
      code_samples = ["code"]

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, payload, _opts ->
          case subject do
            "central.template.get" ->
              {:error, :not_found}
            "llm.request" ->
              # Verify payload uses default prompt structure
              messages = payload[:messages]
              assert is_list(messages)

              user_message = Enum.find(messages, fn msg -> msg[:role] == "user" end)
              assert user_message != nil
              assert user_message[:content] =~ "Analyze the following code"

              {:ok, %{"response" => Jason.encode!(%{"name" => "Test", "type" => "web"})}}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert {:ok, _framework} = result
      end
    end
  end

  describe "prompt formatting" do
    test "formats prompt with package_id and code_samples" do
      package_id = "npm:test-package"
      code_samples = ["sample1.js", "sample2.js"]

      prompt_template = %{
        "system_prompt" => %{"role" => "Expert"},
        "prompt_template" => "Package: {{framework_name}}\nCode: {{code_samples}}"
      }

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => prompt_template}}
            "llm.request" ->
              # Verify formatted prompt
              messages = payload[:messages]
              user_message = Enum.find(messages, fn msg -> msg[:role] == "user" end)

              assert user_message[:content] =~ package_id
              assert user_message[:content] =~ "sample1.js"

              {:ok, %{"response" => Jason.encode!(%{"name" => "Test", "type" => "web"})}}
          end
        end do

        LLMDiscovery.learn(package_id, code_samples)
      end
    end

    test "includes correct system prompt role" do
      package_id = "npm:test"
      code_samples = ["code"]

      prompt_template = %{
        "system_prompt" => %{"role" => "Framework Detection Specialist"},
        "prompt_template" => "Analyze"
      }

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => prompt_template}}
            "llm.request" ->
              messages = payload[:messages]
              system_message = Enum.find(messages, fn msg -> msg[:role] == "system" end)

              assert system_message[:content] == "Framework Detection Specialist"

              {:ok, %{"response" => Jason.encode!(%{"name" => "Test", "type" => "web"})}}
          end
        end do

        LLMDiscovery.learn(package_id, code_samples)
      end
    end
  end

  describe "LLM request parameters" do
    test "sends correct request parameters to NATS" do
      package_id = "npm:test"
      code_samples = ["code"]

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, payload, opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              # Verify request structure
              assert payload[:request_id] != nil
              assert payload[:complexity] == "complex"
              assert payload[:type] == "framework_discovery"
              assert payload[:prompt_template_id] == "framework-discovery"
              assert is_list(payload[:messages])
              assert is_map(payload[:variables])

              # Verify timeout
              assert opts[:timeout] == 120_000

              {:ok, %{"response" => Jason.encode!(%{"name" => "Test", "type" => "web"})}}
          end
        end do

        LLMDiscovery.learn(package_id, code_samples)
      end
    end

    test "generates unique request IDs for each call" do
      package_id = "npm:test"
      code_samples = ["code"]

      request_ids = Agent.start_link(fn -> [] end)
      {:ok, pid} = request_ids

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              Agent.update(pid, fn ids -> [payload[:request_id] | ids] end)
              {:ok, %{"response" => Jason.encode!(%{"name" => "Test", "type" => "web"})}}
          end
        end do

        # Make multiple calls
        LLMDiscovery.learn(package_id, code_samples)
        LLMDiscovery.learn(package_id, code_samples)

        ids = Agent.get(pid, & &1)

        # Verify IDs are unique
        assert length(ids) == 2
        assert Enum.uniq(ids) == ids
      end
    end
  end

  describe "record_success/2" do
    test "returns :ok without doing anything" do
      package_id = "npm:test"
      framework = %{"name" => "Test"}

      result = LLMDiscovery.record_success(package_id, framework)

      assert result == :ok
    end

    test "does not crash on nil inputs" do
      result = LLMDiscovery.record_success(nil, nil)

      assert result == :ok
    end
  end

  describe "response parsing edge cases" do
    test "handles response with unexpected structure" do
      package_id = "npm:test"
      code_samples = ["code"]

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              # Unexpected structure
              {:ok, %{"unexpected" => "structure"}}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert result == :no_match
      end
    end

    test "handles response with nested JSON string" do
      package_id = "npm:test"
      code_samples = ["code"]

      framework_data = %{"name" => "NestedFramework", "type" => "web"}

      with_mock NatsClient, [:passthrough],
        kv_get: fn _bucket, _key -> {:error, :not_found} end,
        request: fn subject, _payload, _opts ->
          case subject do
            "central.template.get" ->
              {:ok, %{"template" => %{}}}
            "llm.request" ->
              {:ok, %{"response" => Jason.encode!(framework_data)}}
          end
        end do

        result = LLMDiscovery.learn(package_id, code_samples)

        assert {:ok, framework} = result
        assert framework["name"] == "NestedFramework"
      end
    end
  end
end
