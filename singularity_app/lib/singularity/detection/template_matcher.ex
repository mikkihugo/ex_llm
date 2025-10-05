defmodule Singularity.TemplateMatcher do
  @moduledoc """
  Matches user requests to code templates using tokenization.

  This is the "intelligence" that helps AI understand what architectural
  patterns to apply, not based on "polite enterprise-ready words" but on
  actual concrete patterns.

  ## Flow

  1. User: "Create NATS consumer with Broadway"
  2. Tokenize → ["create", "nats", "consumer", "broadway"]
  3. Match patterns → finds elixir_production.json NATS pattern
  4. Load relationships → GenServer, supervision, error handling
  5. Return complete template with all architectural knowledge

  ## Example

      iex> TemplateMatcher.find_template("Create API client with retry logic")
      %{
        template: "elixir_production",
        pattern: "http_client",
        score: 8.5,
        includes: ["genserver", "retry", "circuit_breaker", "rate_limit"],
        code_structure: %{...}
      }
  """

  alias Singularity.CodePatternExtractor

  @templates_dir "priv/code_quality_templates"

  @doc """
  Find the best matching template for a user request.
  """
  def find_template(user_request, language \\ :elixir) do
    user_tokens = CodePatternExtractor.extract_from_text(user_request)

    template_file = template_file_for_language(language)
    template_path = Path.join(:code.priv_dir(:singularity), template_file)

    case File.read(template_path) do
      {:ok, content} ->
        template = Jason.decode!(content)
        patterns = extract_patterns(template)

        matches = CodePatternExtractor.find_matching_patterns(user_tokens, patterns)

        case matches do
          [best | _rest] ->
            {:ok, build_response(best, template, user_tokens)}

          [] ->
            {:error, :no_matching_pattern}
        end

      {:error, reason} ->
        {:error, {:template_load_failed, reason}}
    end
  end

  @doc """
  Analyze existing code and find what patterns it uses.
  """
  def analyze_code(code, language \\ :elixir) do
    code_tokens = CodePatternExtractor.extract_from_code(code, language)

    template_file = template_file_for_language(language)
    template_path = Path.join(:code.priv_dir(:singularity), template_file)

    case File.read(template_path) do
      {:ok, content} ->
        template = Jason.decode!(content)
        patterns = extract_patterns(template)

        matches = CodePatternExtractor.find_matching_patterns(code_tokens, patterns)

        {:ok,
         %{
           detected_patterns: Enum.map(matches, & &1.pattern.name),
           tokens: code_tokens,
           suggestions: suggest_missing_patterns(matches, template)
         }}

      {:error, reason} ->
        {:error, {:template_load_failed, reason}}
    end
  end

  # Private functions

  defp template_file_for_language(:elixir), do: "code_quality_templates/elixir_production.json"
  defp template_file_for_language(:gleam), do: "code_quality_templates/gleam_production.json"
  defp template_file_for_language(:rust), do: "code_quality_templates/rust_production.json"

  defp template_file_for_language(:typescript),
    do: "code_quality_templates/typescript_production.json"

  defp template_file_for_language(:python),
    do: "code_quality_templates/python_production.json"

  defp template_file_for_language(_), do: "code_quality_templates/elixir_production.json"

  defp extract_patterns(template) do
    # Extract patterns from the template structure
    # Templates have sections like: patterns, architectural_patterns, etc.

    base_patterns = extract_section_patterns(template["patterns"] || [])

    architectural = extract_section_patterns(template["architectural_patterns"] || [])

    integration = extract_section_patterns(template["integration_patterns"] || [])

    base_patterns ++ architectural ++ integration
  end

  defp extract_section_patterns(section) when is_list(section) do
    Enum.map(section, fn pattern ->
      %{
        name: pattern["name"] || pattern["pattern"] || "unknown",
        keywords: extract_keywords(pattern),
        relationships: pattern["relationships"] || pattern["related"] || [],
        description: pattern["description"] || "",
        code_structure: pattern["structure"] || pattern["example"] || ""
      }
    end)
  end

  defp extract_section_patterns(_), do: []

  defp extract_keywords(pattern) do
    # Keywords can be explicit or derived from name/description
    explicit = pattern["keywords"] || []

    name_tokens =
      if pattern["name"] do
        CodePatternExtractor.extract_from_text(pattern["name"])
      else
        []
      end

    desc_tokens =
      if pattern["description"] do
        pattern["description"]
        |> CodePatternExtractor.extract_from_text()
        |> Enum.take(5)
      else
        []
      end

    (explicit ++ name_tokens ++ desc_tokens)
    |> Enum.uniq()
  end

  defp build_response(match, template, user_tokens) do
    pattern = match.pattern

    # Load related patterns (architectural relationships)
    related_patterns = load_related_patterns(pattern, template)

    %{
      template: template["name"] || "unknown",
      pattern: pattern.name,
      score: match.score,
      matched_keywords: match.matched_keywords,
      user_tokens: user_tokens,
      description: pattern.description,
      code_structure: pattern.code_structure,
      relationships: pattern.relationships,
      related_patterns: related_patterns,
      architectural_guidance: extract_architectural_guidance(pattern, related_patterns)
    }
  end

  defp load_related_patterns(pattern, template) do
    relationship_names = pattern.relationships || []

    all_patterns = extract_patterns(template)

    Enum.filter(all_patterns, fn p ->
      p.name in relationship_names
    end)
  end

  defp extract_architectural_guidance(pattern, related_patterns) do
    # Build the "what actually helps AI" - concrete architectural info
    %{
      primary_pattern: %{
        name: pattern.name,
        structure: pattern.code_structure
      },
      required_patterns:
        Enum.map(related_patterns, fn rp ->
          %{
            name: rp.name,
            why: "#{pattern.name} requires #{rp.name}",
            structure: rp.code_structure
          }
        end),
      integration_points: suggest_integration_points(pattern, related_patterns)
    }
  end

  defp suggest_integration_points(pattern, related_patterns) do
    # Based on relationships, suggest how patterns connect
    Enum.map(related_patterns, fn rp ->
      cond do
        String.contains?(rp.name, "genserver") and String.contains?(pattern.name, "nats") ->
          "GenServer manages NATS connection lifecycle and subscription state"

        String.contains?(rp.name, "supervisor") ->
          "Supervisor restarts #{pattern.name} on failure"

        String.contains?(rp.name, "circuit_breaker") ->
          "Circuit breaker protects #{pattern.name} from cascading failures"

        true ->
          "#{rp.name} supports #{pattern.name}"
      end
    end)
  end

  defp suggest_missing_patterns(matches, template) do
    # If code uses certain patterns, suggest what else it should have
    detected = Enum.map(matches, & &1.pattern.name)

    suggestions = []

    suggestions =
      if "genserver" in detected and "supervisor" not in detected do
        ["Add Supervisor for fault tolerance" | suggestions]
      else
        suggestions
      end

    suggestions =
      if ("http" in detected or "api" in detected) and "circuit_breaker" not in detected do
        ["Add Circuit Breaker for resilience" | suggestions]
      else
        suggestions
      end

    suggestions =
      if "nats" in detected and "health_check" not in detected do
        ["Add health checks for NATS connection" | suggestions]
      else
        suggestions
      end

    suggestions
  end
end
