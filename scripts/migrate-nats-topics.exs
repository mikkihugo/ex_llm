#!/usr/bin/env elixir

# NATS Topic Migration Script
# Migrates existing NATS topics to the new streamlined naming convention

defmodule NatsTopicMigration do
  @moduledoc """
  Migrates NATS topics from old inconsistent naming to new streamlined hierarchy.
  
  Usage:
    elixir scripts/migrate-nats-topics.exs [--dry-run] [--domain=llm]
  """

  # Topic mapping from old to new naming
  @topic_mappings %{
    # LLM Domain (already correct)
    "llm.request" => "llm.request",
    "llm.provider.claude" => "llm.provider.claude",
    "llm.provider.gemini" => "llm.provider.gemini",
    "llm.provider.openai" => "llm.provider.openai",
    
    # System Domain
    "system.engines.list" => "system.engines.list",
    "system.engines.get" => "system.engines.get",
    "system.capabilities.list" => "system.capabilities.list",
    "system.capabilities.available" => "system.capabilities.available",
    "system.health.engines" => "system.health.engines",
    
    # Agent Domain (UPDATED)
    "agent.control.shutdown" => "agent.control.shutdown",
    "agent.events.experiment.completed" => "agent.events.experiment.completed",
    "agent.events.experiment.request" => "agent.events.experiment.request",
    
    # Planning Domain (UPDATED)
    "planning.todo.create" => "planning.todo.create",
    "planning.todo.get" => "planning.todo.get",
    "planning.todo.list" => "planning.todo.list",
    "planning.todo.search" => "planning.todo.search",
    "planning.todo.update" => "planning.todo.update",
    "planning.todo.delete" => "planning.todo.delete",
    "planning.todo.assign" => "planning.todo.assign",
    "planning.todo.complete" => "planning.todo.complete",
    "planning.todo.fail" => "planning.todo.fail",
    "planning.todo.swarm.spawn" => "planning.todo.swarm.spawn",
    "planning.todo.swarm.status" => "planning.todo.swarm.status",
    "planning.todo.stats" => "planning.todo.stats",
    
    # Knowledge Domain
    "knowledge.template.store" => "knowledge.template.store",
    "knowledge.template.get" => "knowledge.template.get",
    "knowledge.template.list" => "knowledge.template.list",
    "knowledge.template.search" => "knowledge.template.search",
    "knowledge.facts.query" => "knowledge.facts.query",
    
    # Analysis Domain (UPDATED)
    "analysis.code.parse" => "analysis.code.parse",
    "analysis.code.embed" => "analysis.code.embed",
    "analysis.code.search" => "analysis.code.search",
    "analysis.meta.registry.naming" => "analysis.meta.registry.naming",
    "analysis.meta.registry.architecture" => "analysis.meta.registry.architecture",
    "analysis.meta.registry.quality" => "analysis.meta.registry.quality",
    "analysis.meta.registry.dependencies" => "analysis.meta.registry.dependencies",
    "analysis.meta.registry.patterns" => "analysis.meta.registry.patterns",
    "analysis.meta.registry.templates" => "analysis.meta.registry.templates",
    "analysis.meta.registry.refactoring" => "analysis.meta.registry.refactoring",
    "analysis.meta.usage.naming" => "analysis.meta.usage.naming",
    "analysis.meta.usage.architecture" => "analysis.meta.usage.architecture",
    "analysis.meta.usage.quality" => "analysis.meta.usage.quality",
    "analysis.meta.usage.dependencies" => "analysis.meta.usage.dependencies",
    "analysis.meta.usage.patterns" => "analysis.meta.usage.patterns",
    "analysis.meta.usage.templates" => "analysis.meta.usage.templates",
    "analysis.meta.usage.refactoring" => "analysis.meta.usage.refactoring",
    
    # Central Domain
    "central.template.search" => "central.template.search",
    "central.template.get" => "central.template.get",
    "central.template.store" => "central.template.store",
    "central.parser.capabilities" => "central.parser.capabilities",
    "central.parser.analytics" => "central.parser.analytics",
    "central.parser.recommendations" => "central.parser.recommendations",
    "central.embedding.models" => "central.embedding.models",
    "central.embedding.usage" => "central.embedding.usage",
    "central.embedding.recommendations" => "central.embedding.recommendations",
    "central.quality.rules" => "central.quality.rules",
    "central.quality.analytics" => "central.quality.analytics",
    "central.quality.recommendations" => "central.quality.recommendations",
    
    # Intelligence Domain
    "intelligence.query" => "intelligence.query.request",
    "intelligence.insights.query" => "intelligence.insights.query",
    "intelligence.quality.aggregate" => "intelligence.quality.aggregate",
    "intelligence.insights.aggregated" => "intelligence.insights.aggregated",
    "intelligence.statistics.global" => "intelligence.statistics.global",
    "intelligence.hub.embeddings" => "intelligence.hub.embeddings",
    
    # Patterns Domain
    "patterns.mined.completed" => "patterns.mined.completed",
    "patterns.mined.failed" => "patterns.mined.failed",
    "patterns.cluster.updated" => "patterns.cluster.updated",
    
    # Packages Domain
    "packages.registry.search" => "packages.registry.search",
    "packages.registry.collect" => "packages.registry.collect",
    
    # Central Cloud Domain (UPDATED)
    "central.knowledge.update" => "central.knowledge.update",
    
    # Tools Domain
    "tools.execute" => "tools.execute.request",
    "tools.code.get" => "tools.code.get",
    "tools.code.search" => "tools.code.search",
    "tools.code.list" => "tools.code.list",
    "tools.symbol.find" => "tools.symbol.find",
    "tools.symbol.refs" => "tools.symbol.refs",
    "tools.symbol.list" => "tools.symbol.list",
    "tools.deps.get" => "tools.deps.get",
    "tools.deps.graph" => "tools.deps.graph",
    
    # Execution Domain
    "execution.request" => "execution.request.task",
    "template.recommend" => "template.recommend",
    
    # Prompt Domain
    "prompt.generate" => "prompt.generate.request",
    "prompt.optimize" => "prompt.optimize.request",
    
    # System Domain (UPDATED)
    "system.events.runner.task.started" => "system.events.runner.task.started",
    "system.events.runner.task.completed" => "system.events.runner.task.completed",
    "system.events.runner.task.failed" => "system.events.runner.task.failed",
    "system.events.runner.circuit.opened" => "system.events.runner.circuit.opened",
    "system.events.runner.circuit.closed" => "system.events.runner.circuit.closed",
    "system.tech.templates" => "system.tech.templates"
  }

  def main(args) do
    dry_run = "--dry-run" in args
    domain_filter = extract_domain_filter(args)
    
    IO.puts("🚀 NATS Topic Migration Script")
    IO.puts("================================")
    IO.puts("Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}")
    IO.puts("Domain Filter: #{domain_filter || "ALL"}")
    IO.puts("")
    
    mappings = if domain_filter do
      filter_by_domain(@topic_mappings, domain_filter)
    else
      @topic_mappings
    end
    
    IO.puts("Found #{map_size(mappings)} topic mappings")
    IO.puts("")
    
    # Group by domain for better organization
    grouped = group_by_domain(mappings)
    
    Enum.each(grouped, fn {domain, topics} ->
      IO.puts("📁 #{String.upcase(domain)} Domain")
      IO.puts(String.duplicate("-", 20))
      
      Enum.each(topics, fn {old_topic, new_topic} ->
        status = if old_topic == new_topic, do: "✅", else: "🔄"
        IO.puts("#{status} #{old_topic} → #{new_topic}")
      end)
      
      IO.puts("")
    end)
    
    if dry_run do
      IO.puts("🔍 DRY RUN COMPLETE - No changes made")
      IO.puts("Run without --dry-run to apply changes")
    else
      IO.puts("⚠️  LIVE MODE - Changes will be applied")
      IO.puts("This script only shows the mappings - actual migration")
      IO.puts("requires updating the source code files manually.")
    end
  end
  
  defp extract_domain_filter(args) do
    case Enum.find(args, fn arg -> String.starts_with?(arg, "--domain=") end) do
      nil -> nil
      arg -> String.replace(arg, "--domain=", "")
    end
  end
  
  defp filter_by_domain(mappings, domain) do
    Enum.filter(mappings, fn {_old, new} ->
      String.starts_with?(new, "#{domain}.")
    end)
  end
  
  defp group_by_domain(mappings) do
    mappings
    |> Enum.group_by(fn {_old, new} ->
      new
      |> String.split(".")
      |> List.first()
    end)
    |> Enum.sort_by(fn {domain, _topics} -> domain end)
  end
end

# Run the script
NatsTopicMigration.main(System.argv())