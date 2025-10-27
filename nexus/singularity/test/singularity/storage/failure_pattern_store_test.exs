defmodule Singularity.Storage.FailurePatternStoreTest do
  use Singularity.DataCase, async: false

  alias Singularity.Schemas.FailurePattern
  alias Singularity.Storage.FailurePatternStore

  describe "insert/2" do
    test "creates a new failure pattern record" do
      attrs = base_attrs()

      assert {:ok, %FailurePattern{} = pattern} = FailurePatternStore.insert(attrs)
      assert pattern.frequency == 1
      assert pattern.story_signature == attrs.story_signature
      assert pattern.failure_mode == attrs.failure_mode
      assert pattern.plan_characteristics == attrs.plan_characteristics
      assert pattern.validation_errors == attrs.validation_errors
      assert pattern.successful_fixes == []
      assert %DateTime{} = pattern.last_seen_at
    end

    test "increments frequency and merges metadata for existing patterns" do
      attrs = base_attrs()
      {:ok, %FailurePattern{} = pattern} = FailurePatternStore.insert(attrs)

      update_attrs =
        attrs
        |> Map.put(:run_id, "run-#{System.unique_integer([:positive])}")
        |> Map.put(:frequency_increment, 2)
        |> Map.put(:successful_fixes, [%{"resolution" => "retry_operation"}])
        |> Map.put(:plan_characteristics, %{"extra" => true})
        |> Map.put(:validation_errors, [%{"type" => "followup_check"}])

      assert {:ok, %FailurePattern{} = updated} = FailurePatternStore.insert(update_attrs)
      assert updated.id == pattern.id
      assert updated.frequency == pattern.frequency + 2
      assert %DateTime{} = updated.last_seen_at

      assert Enum.any?(
               updated.successful_fixes,
               &match?(%{"resolution" => "retry_operation"}, &1)
             )

      assert updated.plan_characteristics["modules"] == attrs.plan_characteristics["modules"]
      assert updated.plan_characteristics["extra"] == true
      assert Enum.any?(updated.validation_errors, &match?(%{"type" => "followup_check"}, &1))
    end
  end

  describe "query/1" do
    test "returns records filtered by failure mode" do
      {:ok, pattern_a} =
        base_attrs(%{failure_mode: "network_error"})
        |> FailurePatternStore.insert()

      {:ok, pattern_b} =
        base_attrs(%{failure_mode: "validation_error", story_signature: "sig-validation"})
        |> FailurePatternStore.insert()

      results = FailurePatternStore.query(%{failure_mode: "network_error"})

      assert [^pattern_a] = results

      results_all = FailurePatternStore.query()

      assert Enum.sort(Enum.map(results_all, & &1.failure_mode)) ==
               Enum.sort(["network_error", "validation_error"])

      assert Enum.any?(results_all, &(&1.id == pattern_b.id))
    end

    test "supports minimum frequency filter" do
      {:ok, _pattern} =
        base_attrs(%{story_signature: "sig-frequency-a"})
        |> FailurePatternStore.insert()

      {:ok, _pattern} =
        base_attrs(%{story_signature: "sig-frequency-a", frequency_increment: 2})
        |> FailurePatternStore.insert()

      {:ok, _pattern} =
        base_attrs(%{story_signature: "sig-frequency-b", failure_mode: "timeout"})
        |> FailurePatternStore.insert()

      results = FailurePatternStore.query(%{min_frequency: 2})
      assert Enum.all?(results, &(&1.frequency >= 2))
      assert Enum.any?(results, &(&1.story_signature == "sig-frequency-a"))
      refute Enum.any?(results, &(&1.story_signature == "sig-frequency-b"))
    end
  end

  describe "find_patterns/1" do
    test "aggregates failure modes by total frequency" do
      base_attrs(%{failure_mode: "duplicate_module", story_signature: "sig-dup-1"})
      |> FailurePatternStore.insert()

      base_attrs(%{failure_mode: "duplicate_module", story_signature: "sig-dup-2"})
      |> FailurePatternStore.insert(%{frequency_increment: 2})

      base_attrs(%{failure_mode: "timeout_error", story_signature: "sig-timeout"})
      |> FailurePatternStore.insert()

      summary = FailurePatternStore.find_patterns(limit: 5)

      duplicate_entry =
        Enum.find(summary, fn entry -> entry.failure_mode == "duplicate_module" end)

      assert duplicate_entry.total_frequency >= 3
      assert is_list(duplicate_entry.story_types)
      assert duplicate_entry.last_seen_at
    end
  end

  describe "find_similar/2" do
    test "matches entries with similar story signatures" do
      base_attrs(%{story_signature: "story-signature-abc"})
      |> FailurePatternStore.insert()

      matches =
        FailurePatternStore.find_similar(%{story_signature: "story-signature-abd"},
          threshold: 0.85,
          limit: 3
        )

      assert [%{pattern: %FailurePattern{}, similarity: score}] = matches
      assert score > 0.85
    end
  end

  describe "get_successful_fixes/1" do
    test "returns unique successful fixes across matching records" do
      base_attrs(%{
        story_signature: "sig-fixes-1",
        successful_fixes: [%{"fix" => "retry"}, %{"fix" => "add_lock"}]
      })
      |> FailurePatternStore.insert()

      base_attrs(%{
        story_signature: "sig-fixes-2",
        successful_fixes: [%{"fix" => "retry"}, %{"fix" => "add_wait"}]
      })
      |> FailurePatternStore.insert()

      fixes = FailurePatternStore.get_successful_fixes()

      assert length(fixes) == 3
      assert Enum.any?(fixes, &match?(%{"fix" => "retry"}, &1))
      assert Enum.any?(fixes, &match?(%{"fix" => "add_lock"}, &1))
      assert Enum.any?(fixes, &match?(%{"fix" => "add_wait"}, &1))
    end
  end

  defp base_attrs(overrides \\ %{}) do
    attrs = %{
      run_id: "run-#{System.unique_integer([:positive])}",
      story_type: Map.get(overrides, :story_type, "integration"),
      story_signature:
        Map.get(overrides, :story_signature, "sig-#{System.unique_integer([:positive])}"),
      failure_mode: Map.get(overrides, :failure_mode, "validation_error"),
      root_cause: Map.get(overrides, :root_cause, "missing validation"),
      plan_characteristics:
        Map.get(overrides, :plan_characteristics, %{
          "modules" => 2,
          "has_external_dependencies" => true
        }),
      validation_state: Map.get(overrides, :validation_state, "failed"),
      validation_errors:
        Map.get(
          overrides,
          :validation_errors,
          [%{"type" => "duplicate_module", "severity" => "critical"}]
        ),
      execution_error:
        Map.get(overrides, :execution_error, "module duplicates existing functionality"),
      successful_fixes: Map.get(overrides, :successful_fixes, [])
    }

    maybe_put_optional(attrs, :frequency_increment, Map.get(overrides, :frequency_increment))
  end

  defp maybe_put_optional(map, _key, nil), do: map
  defp maybe_put_optional(map, key, value), do: Map.put(map, key, value)
end
