defmodule Singularity.Evolution.ConfidenceDistributionTest do
  @moduledoc """
  Tests confidence distribution of evolved rules to determine optimal threshold.
  """
  use ExUnit.Case

  alias Singularity.Evolution.RuleEvolutionSystem

  test "analyze confidence distribution for threshold evaluation" do
    # Get sample rules
    {:ok, rules} = RuleEvolutionSystem.analyze_and_propose_rules(%{}, limit: 100)

    # Should have rules
    assert is_list(rules)

    if length(rules) > 0 do
      confidences = Enum.map(rules, &Map.get(&1, :confidence, 0.0))

      # Calculate statistics
      total = length(rules)
      max_conf = Enum.max(confidences)
      min_conf = Enum.min(confidences)
      avg_conf = Enum.sum(confidences) / length(confidences)

      # Count at different thresholds
      above_90 = Enum.count(rules, &(&1[:confidence] >= 0.90))
      above_85 = Enum.count(rules, &(&1[:confidence] >= 0.85))
      above_80 = Enum.count(rules, &(&1[:confidence] >= 0.80))
      above_75 = Enum.count(rules, &(&1[:confidence] >= 0.75))

      # Print analysis
      IO.puts("\n" <> String.duplicate("=", 60))
      IO.puts("📊 CONFIDENCE DISTRIBUTION ANALYSIS")
      IO.puts(String.duplicate("=", 60))

      IO.puts("\n📈 Statistics:")
      IO.puts("   Total rules: #{total}")
      IO.puts("   Max confidence: #{Float.round(max_conf, 3)}")
      IO.puts("   Min confidence: #{Float.round(min_conf, 3)}")
      IO.puts("   Avg confidence: #{Float.round(avg_conf, 3)}")

      IO.puts("\n📌 Threshold Analysis:")
      IO.puts("   >= 0.90: #{above_90}/#{total} (#{Float.round(above_90 / total * 100, 1)}%)")
      IO.puts("   >= 0.85: #{above_85}/#{total} (#{Float.round(above_85 / total * 100, 1)}%) - CURRENT THRESHOLD")
      IO.puts("   >= 0.80: #{above_80}/#{total} (#{Float.round(above_80 / total * 100, 1)}%)")
      IO.puts("   >= 0.75: #{above_75}/#{total} (#{Float.round(above_75 / total * 100, 1)}%)")

      IO.puts("\n💡 RECOMMENDATION:")

      cond do
        above_85 < 5 and total > 0 ->
          pct_85 = Float.round(above_85 / total * 100, 1)
          pct_80 = Float.round(above_80 / total * 100, 1)
          pct_75 = Float.round(above_75 / total * 100, 1)

          IO.puts("""
          ⚠️  Only #{pct_85}% of rules reach 0.85 threshold.

          RECOMMENDATION: Lower threshold
          • Use 0.80 instead → #{pct_80}% of rules publish
          • Use 0.75 instead → #{pct_75}% of rules publish

          With 0.85 being too high, most rules stay as candidates,
          limiting cross-instance learning. Lower to 0.80-0.75.
          """)

        above_85 >= 20 and above_85 <= 50 ->
          pct_85 = Float.round(above_85 / total * 100, 1)
          pct_90 = Float.round(above_90 / total * 100, 1)

          IO.puts("""
          ✅ Good balance at 0.85 threshold.

          #{pct_85}% of rules publish immediately,
          #{Float.round(above_80 / total * 100, 1)}% are close to threshold.

          OPTIONS:
          • Keep 0.85 for balanced learning (recommended)
          • Raise to 0.90 for stricter gating (#{pct_90}% publish)
          """)

        above_85 > 50 ->
          pct_85 = Float.round(above_85 / total * 100, 1)
          pct_90 = Float.round(above_90 / total * 100, 1)

          IO.puts("""
          📈 Most rules reach 0.85+ (#{pct_85}%).

          RECOMMENDATION: Raise threshold
          • Use 0.90 instead → #{pct_90}% of rules publish
          • Rules are very confident, tighten gate

          This ensures only the most proven rules propagate.
          """)

        true ->
          IO.puts("""
          🤔 Insufficient data to analyze.

          Generate and execute more code to build patterns.
          Need >= 10 execution attempts to synthesize rules.
          """)
      end

      IO.puts("\n🔝 Top 10 Confidences (sorted):")
      top_10 = rules
        |> Enum.map(&Map.get(&1, :confidence, 0.0))
        |> Enum.sort(:desc)
        |> Enum.take(10)

      top_10
      |> Enum.with_index(1)
      |> Enum.each(fn {conf, idx} ->
        bar = String.duplicate("█", round(conf * 20))
        idx_str = String.pad_leading(to_string(idx), 2)
        IO.puts("   #{idx_str}. #{Float.round(conf, 3)} #{bar}")
      end)

      IO.puts("\n" <> String.duplicate("=", 60) <> "\n")

      # Assertions for test
      assert max_conf <= 1.0
      assert min_conf >= 0.0
      assert avg_conf >= 0.0 and avg_conf <= 1.0
    end
  end
end
