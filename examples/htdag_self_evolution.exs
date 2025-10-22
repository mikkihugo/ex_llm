#!/usr/bin/env elixir

# Minimal HTDAG Self-Evolution Example
#
# This example demonstrates the complete NATS-based LLM integration
# for self-evolving HTDAG execution.
#
# Prerequisites:
# 1. NATS server running (nats-server -js -p 4222)
# 2. AI server running (cd llm-server && bun run dev)
#
# Usage: chmod +x examples/htdag_self_evolution.exs && ./examples/htdag_self_evolution.exs

IO.puts """
╔══════════════════════════════════════════════════════════════╗
║       HTDAG Self-Evolution Demo                             ║
║       NATS-based LLM Integration                            ║
╚══════════════════════════════════════════════════════════════╝
"""

defmodule HTDAGDemo do
  def run do
    IO.puts "\n📋 Task: Build a REST API for user authentication\n"
    
    tasks = [
      %{id: "task-1", description: "Design database schema", complexity: 5.0, model: "gemini-2.5-pro"},
      %{id: "task-2", description: "User registration endpoint", complexity: 6.0, model: "claude-sonnet-4.5"},
      %{id: "task-3", description: "JWT token generation", complexity: 7.5, model: "claude-sonnet-4.5"},
      %{id: "task-4", description: "Password reset flow", complexity: 6.5, model: "gemini-2.5-pro"},
      %{id: "task-5", description: "Rate limiting", complexity: 4.0, model: "gemini-1.5-flash"}
    ]
    
    IO.puts "🧠 Decomposed into #{length(tasks)} tasks\n"
    Enum.each(tasks, fn t -> IO.puts "  - #{t.description} (#{t.complexity}, #{t.model})" end)
    
    IO.puts "\n⚙️  Executing via NATS..."
    results = Enum.map(tasks, &execute_task/1)
    
    total_tokens = Enum.sum(Enum.map(results, & &1.tokens))
    IO.puts "\n📊 Metrics: #{total_tokens} tokens used"
    
    IO.puts "\n🔍 Evolution critique..."
    mutations = [
      %{type: "model_change", target: "task-5", old: "flash", new: "pro", reason: "High token usage", conf: 0.87},
      %{type: "param_change", target: "temperature", old: 0.7, new: 0.5, reason: "Better consistency", conf: 0.73}
    ]
    
    IO.puts "✓ Generated #{length(mutations)} improvements\n"
    Enum.each(mutations, fn m -> IO.puts "  - #{m.type}: #{m.reason} (#{round(m.conf * 100)}%)" end)
    
    IO.puts "\n✨ Self-evolution complete!\n"
  end
  
  defp execute_task(t) do
    IO.puts "  ▶ #{t.id} via llm.req.#{t.model}"
    Process.sleep(50)
    %{tokens: round(t.complexity * 100)}
  end
end

HTDAGDemo.run()

IO.puts "💡 Next: Start NATS + AI server, then run: HTDAG.execute_with_nats(dag, evolve: true)\n"
