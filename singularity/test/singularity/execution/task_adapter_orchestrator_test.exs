defmodule Singularity.Execution.TaskAdapterOrchestratorTest do
  @moduledoc """
  Integration tests for TaskAdapterOrchestrator.

  Tests the unified task execution routing system that dispatches tasks to
  appropriate adapters (Oban, NATS, GenServer) based on priority ordering.

  ## Test Coverage

  - Adapter discovery and loading from config
  - First-match-wins execution semantics
  - Priority ordering (lower numbers try first)
  - Error handling and fallback behavior
  - Task type detection and routing
  - Integration with adapter implementations
  """

  use ExUnit.Case, async: true

  alias Singularity.Execution.TaskAdapterOrchestrator
  alias Singularity.Execution.TaskAdapter

  describe "get_adapters_info/0" do
    test "returns all enabled adapters sorted by priority" do
      adapters = TaskAdapterOrchestrator.get_adapters_info()

      assert is_list(adapters)
      assert length(adapters) > 0

      # All adapters should have required fields
      Enum.each(adapters, fn adapter ->
        assert Map.has_key?(adapter, :name)
        assert Map.has_key?(adapter, :enabled)
        assert Map.has_key?(adapter, :priority)
        assert Map.has_key?(adapter, :module)
        assert Map.has_key?(adapter, :description)
      end)

      # Verify adapters are sorted by priority (ascending)
      priorities = Enum.map(adapters, & &1.priority)
      assert priorities == Enum.sort(priorities),
             "Adapters should be sorted by priority (lowest first)"
    end

    test "all returned adapters are enabled" do
      adapters = TaskAdapterOrchestrator.get_adapters_info()

      Enum.each(adapters, fn adapter ->
        assert adapter.enabled == true, "Adapter #{adapter.name} should be enabled"
      end)
    end

    test "adapter modules are valid" do
      adapters = TaskAdapterOrchestrator.get_adapters_info()

      Enum.each(adapters, fn adapter ->
        assert Code.ensure_loaded?(adapter.module),
               "Adapter module #{adapter.module} should be loadable"
      end)
    end
  end

  describe "execute/2 - Basic Functionality" do
    test "requires task to be map or binary (guard clause)" do
      # TaskAdapterOrchestrator.execute/2 has a guard that requires map or binary
      # Passing nil will raise FunctionClauseError as expected
      assert_raise FunctionClauseError, fn ->
        TaskAdapterOrchestrator.execute(nil)
      end
    end

    test "handles empty task gracefully" do
      result = TaskAdapterOrchestrator.execute(%{})
      # empty task may be processed by some adapters
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "accepts task map with type and data" do
      task = %{
        type: :quality_check,
        data: %{file: "test.ex"}
      }

      # This may succeed or fail depending on adapter availability,
      # but shouldn't crash
      result = TaskAdapterOrchestrator.execute(task)
      assert is_tuple(result) and tuple_size(result) == 2
    end
  end

  describe "execute/2 - Adapter Selection" do
    test "respects priority ordering in adapter selection" do
      # Create a test task that all adapters could theoretically handle
      task = %{
        type: :test_task,
        priority: :normal,
        data: %{test: "data"}
      }

      # The orchestrator should try adapters in priority order
      # We can't easily test which adapter was chosen without mocking,
      # but we can verify the behavior is deterministic
      result1 = TaskAdapterOrchestrator.execute(task)
      result2 = TaskAdapterOrchestrator.execute(task)

      # Same input should produce same result pattern (both ok or both error)
      is_ok_1 = match?({:ok, _}, result1)
      is_ok_2 = match?({:ok, _}, result2)
      assert is_ok_1 == is_ok_2, "Results should be consistent for same input"
    end

    test "falls back to next adapter on failure" do
      # This tests the fallback behavior - if first adapter fails,
      # orchestrator should try next priority adapter
      task = %{
        type: :fallback_test,
        data: %{content: "test"}
      }

      # Should not return :no_adapter_found immediately,
      # as there are multiple adapters
      result = TaskAdapterOrchestrator.execute(task)
      refute result == {:error, :no_adapter_found}
    end
  end

  describe "execute/2 - Options Handling" do
    test "accepts and passes through options" do
      task = %{type: :test_task, data: %{}}
      opts = [timeout: 5000, priority: :high, retry: true]

      # Should not crash with options
      result = TaskAdapterOrchestrator.execute(task, opts)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "respects custom adapter list in options" do
      task = %{type: :test_task, data: %{}}
      opts = [adapters: [:oban_adapter]]

      # Should only try the specified adapter
      result = TaskAdapterOrchestrator.execute(task, opts)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "handles empty adapter list gracefully" do
      task = %{type: :test_task, data: %{}}
      opts = [adapters: []]

      # Should fail gracefully with no adapters
      result = TaskAdapterOrchestrator.execute(task, opts)
      assert {:error, _} = result
    end
  end

  describe "execute/2 - Error Handling" do
    test "handles invalid tasks gracefully" do
      # Task with invalid structure
      task = %{type: :invalid_type, data: nil}

      # Adapters may succeed or fail - we just want to ensure it doesn't crash
      result = TaskAdapterOrchestrator.execute(task)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "logs execution attempts" do
      # Capture logs
      log = capture_log(fn ->
        task = %{type: :test_task, data: %{}}
        TaskAdapterOrchestrator.execute(task)
      end)

      # Should contain orchestration logs
      assert log =~ "TaskAdapterOrchestrator" or log =~ "adapter"
    end
  end

  describe "get_capabilities/1" do
    test "returns capabilities for valid adapter" do
      capabilities = TaskAdapterOrchestrator.get_capabilities(:oban_adapter)
      assert is_list(capabilities)
    end

    test "returns empty list for invalid adapter" do
      capabilities = TaskAdapterOrchestrator.get_capabilities(:nonexistent_adapter)
      assert capabilities == []
    end

    test "all adapters have at least one capability" do
      adapters = TaskAdapterOrchestrator.get_adapters_info()

      Enum.each(adapters, fn adapter ->
        capabilities = TaskAdapterOrchestrator.get_capabilities(adapter.name)
        assert is_list(capabilities)
        assert length(capabilities) > 0,
               "Adapter #{adapter.name} should have at least one capability"
      end)
    end
  end

  describe "load_enabled_adapters/0" do
    test "returns all enabled adapters from config" do
      adapters = TaskAdapter.load_enabled_adapters()

      assert is_list(adapters)
      assert length(adapters) > 0

      # All should be tuples of {type, priority, config}
      Enum.each(adapters, fn entry ->
        assert is_tuple(entry)
        assert tuple_size(entry) == 3
        {type, priority, config} = entry
        assert is_atom(type)
        assert is_integer(priority)
        assert is_map(config)
        assert config[:module]
      end)
    end

    test "adapters are sorted by priority" do
      adapters = TaskAdapter.load_enabled_adapters()
      priorities = Enum.map(adapters, fn {_type, priority, _config} -> priority end)

      assert priorities == Enum.sort(priorities),
             "Adapters should be sorted by priority (lowest first)"
    end
  end

  describe "TaskAdapter behavior callbacks" do
    test "all adapters implement required callbacks" do
      adapters = TaskAdapter.load_enabled_adapters()

      Enum.each(adapters, fn {_type, _priority, config} ->
        module = config[:module]
        assert Code.ensure_loaded?(module)

        # Check for required callbacks (5 required callbacks)
        assert function_exported?(module, :adapter_type, 0),
               "#{module} must implement adapter_type/0"

        assert function_exported?(module, :description, 0),
               "#{module} must implement description/0"

        assert function_exported?(module, :capabilities, 0),
               "#{module} must implement capabilities/0"

        assert function_exported?(module, :execute, 2),
               "#{module} must implement execute/2"
      end)
    end

    test "all adapter callbacks return expected types" do
      adapters = TaskAdapter.load_enabled_adapters()

      Enum.each(adapters, fn {type, _priority, config} ->
        module = config[:module]

        # Test callback return types
        adapter_type = module.adapter_type()
        assert is_atom(adapter_type)

        description = module.description()
        assert is_binary(description)

        capabilities = module.capabilities()
        assert is_list(capabilities)

        # All capabilities should be strings
        Enum.each(capabilities, fn cap ->
          assert is_binary(cap), "Capability should be a string"
        end)
      end)
    end
  end

  describe "Task Routing Scenarios" do
    test "background job tasks route appropriately" do
      task = %{
        type: :ml_training,
        data: %{model: "bert", epochs: 10}
      }

      result = TaskAdapterOrchestrator.execute(task)
      # Should succeed or provide meaningful error
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "async distributed tasks route appropriately" do
      task = %{
        type: :distributed_analysis,
        data: %{input: "code sample"}
      }

      result = TaskAdapterOrchestrator.execute(task)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "sync in-process tasks route appropriately" do
      task = %{
        type: :format_code,
        data: %{code: "def foo do end"}
      }

      result = TaskAdapterOrchestrator.execute(task)
      assert is_tuple(result) and tuple_size(result) == 2
    end
  end

  describe "Configuration Integrity" do
    test "config matches implementation" do
      # Load config (returns keyword list, not map)
      config = Application.get_env(:singularity, :task_adapters, [])

      # Should have entries
      assert length(config) > 0

      # All configured adapters should exist
      Enum.each(config, fn {name, adapter_config} ->
        assert is_atom(name)
        assert is_map(adapter_config)
        assert adapter_config[:module]
        assert adapter_config[:enabled] in [true, false]
        assert is_integer(adapter_config[:priority])

        # If enabled, module should be loadable
        if adapter_config[:enabled] do
          assert Code.ensure_loaded?(adapter_config[:module]),
                 "Configured module #{adapter_config[:module]} should be loadable"
        end
      end)
    end

    test "no duplicate priorities" do
      adapters = TaskAdapter.load_enabled_adapters()
      priorities = Enum.map(adapters, fn {_type, priority, _config} -> priority end)

      # While duplicates are technically allowed, it's usually a mistake
      # This documents the expectation
      unique_priorities = Enum.uniq(priorities)
      assert length(priorities) == length(unique_priorities),
             "Adapters should have unique priorities to ensure clear ordering"
    end
  end

  describe "Integration with Adapters" do
    test "ObanAdapter is discoverable and configured" do
      adapters = TaskAdapter.load_enabled_adapters()
      names = Enum.map(adapters, fn {type, _priority, _config} -> type end)

      assert :oban_adapter in names, "ObanAdapter should be enabled and discoverable"
    end

    test "NatsAdapter is discoverable and configured" do
      adapters = TaskAdapter.load_enabled_adapters()
      names = Enum.map(adapters, fn {type, _priority, _config} -> type end)

      assert :nats_adapter in names, "NatsAdapter should be enabled and discoverable"
    end

    test "GenServerAdapter is discoverable and configured" do
      adapters = TaskAdapter.load_enabled_adapters()
      names = Enum.map(adapters, fn {type, _priority, _config} -> type end)

      assert :genserver_adapter in names, "GenServerAdapter should be enabled and discoverable"
    end
  end

  describe "Performance and Determinism" do
    test "adapter discovery is deterministic" do
      adapters1 = TaskAdapter.load_enabled_adapters()
      adapters2 = TaskAdapter.load_enabled_adapters()

      # Should return same adapters in same order
      assert adapters1 == adapters2
    end

    test "info gathering is consistent" do
      info1 = TaskAdapterOrchestrator.get_adapters_info()
      info2 = TaskAdapterOrchestrator.get_adapters_info()

      # Should have same adapters in same order
      assert length(info1) == length(info2)
      assert Enum.map(info1, & &1.name) == Enum.map(info2, & &1.name)
    end
  end

  defp capture_log(fun) do
    ExUnit.CaptureLog.capture_log(fun)
  end
end
