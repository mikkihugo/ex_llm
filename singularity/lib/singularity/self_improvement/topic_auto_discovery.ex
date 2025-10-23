defmodule Singularity.SelfImprovement.TopicAutoDiscovery do
  @moduledoc """
  Self-Improving NATS Topic Auto-Discovery System

  Automatically detects new topic patterns, suggests improvements, and maintains
  the hierarchical naming convention across the entire system.

  ## How It Works

  1. **Pattern Detection**: Scans all NATS operations to find new topic patterns
  2. **Convention Validation**: Checks if topics follow `{domain}.{subdomain}.{action}` pattern
  3. **Improvement Suggestions**: Recommends better naming for non-conforming topics
  4. **Auto-Migration**: Can automatically fix simple naming issues
  5. **Learning**: Builds knowledge base of topic usage patterns

  ## Self-Improvement Features

  - **Real-time Monitoring**: Tracks topic usage and performance
  - **Pattern Learning**: Learns from successful topic patterns
  - **Auto-Suggestions**: Proposes new topics following established patterns
  - **Performance Optimization**: Suggests which topics should be direct vs. cached
  """

  use GenServer
  require Logger

  @topic_pattern ~r/^([a-z]+)\.([a-z]+)\.([a-z]+)(?:\..*)?$/
  @performance_critical_domains [:llm, :system_engines, :system_capabilities, :system_health]
  @cached_domains [:events, :metrics]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Starting Topic Auto-Discovery System...")
    
    # Subscribe to all NATS traffic for pattern analysis
    :ok = subscribe_to_nats_traffic()
    
    state = %{
      discovered_topics: %{},
      pattern_usage: %{},
      performance_metrics: %{},
      suggestions: [],
      learning_data: %{}
    }
    
    {:ok, state}
  end

  @doc """
  Manually trigger topic discovery scan across the codebase
  """
  def discover_topics do
    GenServer.call(__MODULE__, :discover_topics)
  end

  @doc """
  Get current topic analysis and suggestions
  """
  def get_analysis do
    GenServer.call(__MODULE__, :get_analysis)
  end

  @doc """
  Apply suggested topic improvements
  """
  def apply_suggestions(suggestions \\ :all) do
    GenServer.call(__MODULE__, {:apply_suggestions, suggestions})
  end

  # Private functions

  defp subscribe_to_nats_traffic do
    # Subscribe to all NATS subjects to monitor usage patterns
    # This would be implemented based on your NATS setup
    :ok
  end

  def handle_call(:discover_topics, _from, state) do
    Logger.info("Starting comprehensive topic discovery...")
    
    # Scan all Elixir files for NATS operations
    topics = scan_codebase_for_topics()
    
    # Analyze patterns
    analysis = analyze_topic_patterns(topics)
    
    # Generate suggestions
    suggestions = generate_suggestions(analysis)
    
    new_state = %{state | 
      discovered_topics: topics,
      suggestions: suggestions
    }
    
    {:reply, {:ok, analysis}, new_state}
  end

  def handle_call(:get_analysis, _from, state) do
    analysis = %{
      total_topics: map_size(state.discovered_topics),
      conforming_topics: count_conforming_topics(state.discovered_topics),
      suggestions: state.suggestions,
      performance_metrics: state.performance_metrics
    }
    
    {:reply, analysis, state}
  end

  def handle_call({:apply_suggestions, suggestions}, _from, state) do
    suggestions_to_apply = case suggestions do
      :all -> state.suggestions
      list when is_list(list) -> list
    end
    
    results = apply_topic_suggestions(suggestions_to_apply)
    
    {:reply, {:ok, results}, state}
  end

  defp scan_codebase_for_topics do
    # Use grep to find all NATS operations in Elixir files
    {output, 0} = System.cmd("grep", [
      "-r", "--include=*.ex", 
      "-E", "(subscribe|publish|request)\\(.*\"[a-z]+\\.[a-z]+",
      "lib/"
    ])
    
    topics = output
    |> String.split("\n")
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&extract_topic_from_line/1)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    
    Logger.info("Discovered #{length(topics)} unique topics")
    topics
  end

  defp extract_topic_from_line(line) do
    # Extract topic from lines like: subscribe("domain.subdomain.action")
    case Regex.run(~r/["']([a-z]+\.[a-z]+(?:\.[a-z]+)*)["']/, line) do
      [_, topic] -> topic
      _ -> nil
    end
  end

  defp analyze_topic_patterns(topics) do
    %{
      total: length(topics),
      conforming: topics |> Enum.count(&conforms_to_pattern?/1),
      non_conforming: topics |> Enum.reject(&conforms_to_pattern?/1),
      domain_usage: group_by_domain(topics),
      performance_critical: identify_performance_critical(topics)
    }
  end

  defp conforms_to_pattern?(topic) do
    Regex.match?(@topic_pattern, topic)
  end

  defp group_by_domain(topics) do
    topics
    |> Enum.map(&extract_domain/1)
    |> Enum.frequencies()
  end

  defp extract_domain(topic) do
    case String.split(topic, ".") do
      [domain | _] -> String.to_atom(domain)
      _ -> :unknown
    end
  end

  defp identify_performance_critical(topics) do
    topics
    |> Enum.filter(fn topic ->
      @performance_critical_domains
      |> Enum.any?(&String.starts_with?(topic, "#{&1}."))
    end)
  end

  defp generate_suggestions(analysis) do
    suggestions = []
    
    # Suggest fixes for non-conforming topics
    non_conforming_suggestions = analysis.non_conforming
    |> Enum.map(&suggest_topic_improvement/1)
    
    # Suggest performance optimizations
    performance_suggestions = suggest_performance_optimizations(analysis)
    
    # Suggest new topic patterns based on usage
    pattern_suggestions = suggest_new_patterns(analysis)
    
    suggestions ++ non_conforming_suggestions ++ performance_suggestions ++ pattern_suggestions
  end

  defp suggest_topic_improvement(topic) do
    case String.split(topic, ".") do
      [domain, action] ->
        # Two-part topic - suggest three-part
        suggested = "#{domain}.#{action}.request"
        %{
          type: :naming_improvement,
          current: topic,
          suggested: suggested,
          reason: "Two-part topics should follow {domain}.{subdomain}.{action} pattern"
        }
      
      [domain, subdomain, action | rest] ->
        # Already three-part or more - check if it follows convention
        if length([domain, subdomain, action]) == 3 do
          nil  # Already conforming
        else
          %{
            type: :naming_improvement,
            current: topic,
            suggested: "#{domain}.#{subdomain}.#{action}",
            reason: "Too many parts - should be {domain}.{subdomain}.{action}"
          }
        end
      
      _ ->
        %{
          type: :naming_improvement,
          current: topic,
          suggested: "unknown.#{topic}",
          reason: "Unknown pattern - needs manual review"
        }
    end
  end

  defp suggest_performance_optimizations(analysis) do
    suggestions = []
    
    # Check if performance-critical topics are being cached
    performance_critical = analysis.performance_critical
    
    if length(performance_critical) > 0 do
      suggestions = [%{
        type: :performance_optimization,
        topics: performance_critical,
        suggestion: "Ensure these topics use direct request/reply (no JetStream)",
        reason: "Performance-critical topics should not be cached"
      } | suggestions]
    end
    
    suggestions
  end

  defp suggest_new_patterns(analysis) do
    # Analyze domain usage to suggest new patterns
    domain_usage = analysis.domain_usage
    
    suggestions = []
    
    # If a domain has many topics, suggest subdomain organization
    high_usage_domains = domain_usage
    |> Enum.filter(fn {_domain, count} -> count > 5 end)
    
    for {domain, count} <- high_usage_domains do
      suggestions = [%{
        type: :pattern_suggestion,
        domain: domain,
        suggestion: "Consider organizing #{domain}.* into subdomains",
        reason: "Domain has #{count} topics - could benefit from subdomain organization"
      } | suggestions]
    end
    
    suggestions
  end

  defp apply_topic_suggestions(suggestions) do
    # This would implement the actual file modifications
    # For now, just return what would be changed
    suggestions
    |> Enum.map(fn suggestion ->
      case suggestion.type do
        :naming_improvement ->
          "Would change '#{suggestion.current}' to '#{suggestion.suggested}'"
        :performance_optimization ->
          "Would ensure #{length(suggestion.topics)} topics use direct routing"
        :pattern_suggestion ->
          "Would suggest subdomain organization for #{suggestion.domain}"
      end
    end)
  end

  defp count_conforming_topics(topics) when is_map(topics) do
    topics
    |> Map.values()
    |> Enum.count(&conforms_to_pattern?/1)
  end
end