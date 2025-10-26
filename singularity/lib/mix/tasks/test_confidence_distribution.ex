defmodule Mix.Tasks.TestConfidenceDistribution do
  @moduledoc "Test confidence distribution of evolved rules"

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    alias Singularity.Evolution.RuleEvolutionSystem

    IO.puts("\n🧪 Testing Confidence Distribution of Evolved Rules...\n")

    case RuleEvolutionSystem.analyze_and_propose_rules(%{}, limit: 100) do
      {:ok, rules} ->
        confidences = Enum.map(rules, &Map.get(&1, :confidence, 0.0))

        result = %{
          total_rules: length(rules),
          max: Enum.max(confidences, fn -> 0.0 end),
          min: Enum.min(confidences, fn -> 0.0 end),
          avg: Float.round(Enum.sum(confidences) / max(length(confidences), 1), 3),
          above_90: Enum.count(rules, &(&1[:confidence] >= 0.90)),
          above_85: Enum.count(rules, &(&1[:confidence] >= 0.85)),
          above_80: Enum.count(rules, &(&1[:confidence] >= 0.80)),
          above_75: Enum.count(rules, &(&1[:confidence] >= 0.75)),
          above_70: Enum.count(rules, &(&1[:confidence] >= 0.70)),
          below_70: Enum.count(rules, &(&1[:confidence] < 0.70))
        }

        IO.inspect(result, label: "📊 Confidence Distribution", pretty: true)

        IO.puts("\n📈 Analysis:")
        IO.puts("   Total rules analyzed: #{result.total_rules}")
        IO.puts("   Avg confidence: #{result.avg}")
        IO.puts("   Range: #{result.min} - #{result.max}")

        IO.puts("\n📌 Publishing Threshold Analysis:")

        if result.above_85 > 0 do
          pct = Float.round(result.above_85 / result.total_rules * 100, 1)
          IO.puts("   ✅ At 0.85: #{result.above_85}/#{result.total_rules} rules (#{pct}%)")
        else
          IO.puts("   ❌ At 0.85: #{result.above_85}/#{result.total_rules} rules (0%)")
        end

        if result.above_80 > 0 do
          pct = Float.round(result.above_80 / result.total_rules * 100, 1)
          IO.puts("   🟡 At 0.80: #{result.above_80}/#{result.total_rules} rules (#{pct}%)")
        else
          IO.puts("   🟡 At 0.80: #{result.above_80}/#{result.total_rules} rules (0%)")
        end

        if result.above_75 > 0 do
          pct = Float.round(result.above_75 / result.total_rules * 100, 1)
          IO.puts("   🟠 At 0.75: #{result.above_75}/#{result.total_rules} rules (#{pct}%)")
        else
          IO.puts("   🟠 At 0.75: #{result.above_75}/#{result.total_rules} rules (0%)")
        end

        IO.puts("\n💡 Recommendation:")

        cond do
          result.above_85 < 5 and result.total_rules > 0 ->
            pct = Float.round(result.above_85 / result.total_rules * 100, 1)

            IO.puts("""
            ⚠️  Only #{pct}% of rules reach 0.85 threshold.

            Consider LOWERING threshold to:
            • 0.80 - Most rules would publish (#{Float.round(result.above_80 / result.total_rules * 100, 1)}%)
            • 0.75 - More aggressive learning (#{Float.round(result.above_75 / result.total_rules * 100, 1)}%)
            """)

          result.above_85 >= 20 and result.above_85 <= 50 ->
            pct = Float.round(result.above_85 / result.total_rules * 100, 1)

            IO.puts("""
            ✅ Good balance at 0.85 threshold.

            #{pct}% of rules publish immediately, #{Float.round(result.above_80 / result.total_rules * 100, 1)}% are close.
            Consider keeping 0.85 or bumping to 0.90 for stricter gating.
            """)

          result.above_85 > 50 ->
            pct = Float.round(result.above_85 / result.total_rules * 100, 1)

            IO.puts("""
            📈 Most rules reach 0.85+ (#{pct}%).

            Consider RAISING threshold to:
            • 0.90 - Stricter quality gate (#{Float.round(result.above_90 / result.total_rules * 100, 1)}%)
            • 0.95 - Only highest confidence rules
            """)

          true ->
            IO.puts("🤔 No rules generated yet. Run code generation to build patterns.")
        end

        # Show actual top confidences
        if length(rules) > 0 do
          IO.puts("\n🔝 Top 10 Rule Confidences:")

          rules
          |> Enum.map(&Map.get(&1, :confidence, 0.0))
          |> Enum.sort(:desc)
          |> Enum.take(10)
          |> Enum.with_index(1)
          |> Enum.each(fn {conf, idx} ->
            bar = String.duplicate("█", round(conf * 20))
            IO.puts("   #{idx}. #{conf} #{bar}")
          end)
        end

      {:error, reason} ->
        IO.puts("❌ Error analyzing rules: #{inspect(reason)}")
    end

    IO.puts("\n")
  end
end
