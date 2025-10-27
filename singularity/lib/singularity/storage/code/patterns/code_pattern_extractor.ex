defmodule Singularity.CodePatternExtractor do
  @moduledoc """
  Extracts architectural patterns from user requests and existing code.

  **What it does:** Answers "What architectural patterns does this code use?"

  **How:** Keyword matching on concrete technical terms (genserver, nats, async)
  not marketing fluff ("enterprise-ready", "production-grade").

  ## Pattern Categories Extracted

  - **Process patterns**: GenServer, Supervisor, Broadway, Actor
  - **Integration**: NATS, HTTP, Database, Kafka, Message queues
  - **Resilience**: Circuit breakers, retry logic, error handling
  - **Concurrency**: Async/await, processes, supervision trees
  - **Data**: Serialization, validation, caching

  ## Usage Examples

      # What patterns does user want?
      iex> CodePatternExtractor.extract_from_text("Create message consumer")
      ["create", "message", "consumer", "messaging"]

      # What patterns does this code already use?
      iex> code = "use GenServer\\ndef handle_call..."
      iex> CodePatternExtractor.extract_from_code(code, :elixir)
      ["genserver", "state", "synchronous", "handle_call"]

      # Which template patterns match?
      iex> CodePatternExtractor.find_matching_patterns(keywords, template_patterns)
      [%{score: 4.0, pattern: "messaging_microservice", matched: ["message", "consumer"]}]
  """

  @type pattern_keyword :: String.t()
  @type pattern :: %{
          name: String.t(),
          keywords: [String.t()],
          relationships: [String.t()],
          weight: float()
        }

  @doc """
  Extract architectural keywords from user text.

  Normalizes text into technical terms:
  - Lowercase
  - Remove punctuation & stop words
  - Split camelCase/snake_case
  - Keep only meaningful keywords

  ## Examples

      iex> extract_from_text("Create an API client")
      ["create", "api", "client"]

      iex> extract_from_text("genServerWithMessaging")
      ["gen", "server", "messaging"]
  """
  @spec extract_from_text(String.t()) :: [pattern_keyword()]
  def extract_from_text(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, " ")
    # Split camelCase: "apiClient" -> "api client"
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
    # Split snake_case
    |> String.replace("_", " ")
    |> String.split()
    |> remove_stop_words()
    |> Enum.uniq()
  end

  @doc """
  Find which architectural patterns match extracted keywords.

  **Scoring:**
  - Exact keyword match: 2.0 points
  - Pattern name match: 1.0 point
  - Related pattern match: 0.5 points

  Returns sorted by score (highest first).

  ## Examples

      iex> patterns = [%{name: "message_consumer", keywords: ["message", "consumer"]}]
      iex> find_matching_patterns(["message", "consumer"], patterns)
      [%{score: 4.0, pattern: "message_consumer", matched_keywords: ["message", "consumer"]}]
  """
  @spec find_matching_patterns([pattern_keyword()], [pattern()]) :: [
          %{score: float(), pattern: pattern(), matched_keywords: [pattern_keyword()]}
        ]
  def find_matching_patterns(keywords, patterns) do
    patterns
    |> Enum.map(&score_pattern(&1, keywords))
    |> Enum.filter(fn %{score: score} -> score > 0 end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc """
  Extract architectural patterns from existing code.

  **Language-specific detection:**
  - **Elixir**: GenServer, Supervisor, Broadway, NATS, Phoenix
  - **Gleam**: Actor, Supervisor, HTTP client
  - **Rust**: Async/tokio, Serde, NATS, async-trait

  Returns concrete architectural keywords, not generic terms.

  ## Examples

      # Elixir GenServer
      iex> code = "use GenServer\\ndef handle_call(:get, _from, state)"
      iex> extract_from_code(code, :elixir)
      ["genserver", "synchronous", "state", "handle_call"]

      # Rust async
      iex> code = "async fn fetch() { reqwest::get(url).await }"
      iex> extract_from_code(code, :rust)
      ["async", "concurrent", "http"]
  """
  @spec extract_from_code(String.t(), atom()) :: [pattern_keyword()]
  def extract_from_code(code, language) do
    case language do
      :elixir -> extract_elixir_patterns(code)
      :gleam -> extract_gleam_patterns(code)
      :rust -> extract_rust_patterns(code)
      _ -> extract_from_text(code)
    end
  end

  # Private functions

  defp remove_stop_words(tokens) do
    stop_words = ~w(a an the is are was were be been being have has had
                    do does did will would should could may might must
                    can to of in on at by for with from as)

    Enum.reject(tokens, &(&1 in stop_words))
  end

  defp score_pattern(pattern, user_keywords) do
    pattern_keywords = pattern[:keywords] || []
    pattern_name_keywords = extract_from_text(pattern[:name] || "")

    # Calculate overlap score
    keyword_matches = count_matches(user_keywords, pattern_keywords)
    name_matches = count_matches(user_keywords, pattern_name_keywords)

    # Weight: exact keyword matches worth more
    base_score = keyword_matches * 2.0 + name_matches * 1.0

    # Bonus for relationship matches (architectural context)
    relationship_bonus =
      if pattern[:relationships] do
        pattern[:relationships]
        |> Enum.flat_map(&extract_from_text/1)
        |> count_matches(user_keywords)
        |> Kernel.*(0.5)
      else
        0.0
      end

    total_score = base_score + relationship_bonus

    %{
      score: total_score,
      pattern: pattern,
      matched_keywords: Enum.filter(pattern_keywords, &(&1 in user_keywords))
    }
  end

  defp count_matches(keywords1, keywords2) do
    set1 = MapSet.new(keywords1)
    set2 = MapSet.new(keywords2)
    MapSet.intersection(set1, set2) |> MapSet.size()
  end

  defp extract_elixir_patterns(code) do
    patterns = [
      # OTP patterns
      {~r/use\s+GenServer/i, ["genserver", "state", "concurrent", "otp"]},
      {~r/use\s+Supervisor/i, ["supervisor", "children", "fault_tolerance", "otp"]},
      {~r/use\s+Broadway/i, ["broadway", "pipeline", "stream", "data_flow"]},
      {~r/use\s+Phoenix\.Channel/i, ["channel", "websocket", "pubsub", "realtime"]},
      {~r/use\s+Ecto\.Schema/i, ["schema", "database", "changeset", "validation"]},

      # NATS/Messaging
      {~r/Gnat\./i, ["nats", "messaging", "pubsub"]},
      {~r/jetstream/i, ["jetstream", "nats", "streaming", "persistence"]},

      # HTTP
      {~r/Tesla\./i, ["http", "client", "api", "rest"]},
      {~r/Req\./i, ["http", "client", "api", "rest"]},
      {~r/Plug\./i, ["http", "middleware", "web", "server"]},

      # GenServer callbacks (architectural signals)
      {~r/handle_call/i, ["genserver", "synchronous", "request_reply"]},
      {~r/handle_cast/i, ["genserver", "asynchronous", "fire_and_forget"]},
      {~r/handle_info/i, ["genserver", "message", "event"]},
      {~r/def\s+start_link/i, ["supervisor", "init", "lifecycle"]},

      # Error handling patterns
      {~r/with\s+/i, ["error_handling", "railway_pattern"]},
      {~r/case.*do/i, ["pattern_matching", "control_flow"]},

      # Testing
      {~r/describe\s+/i, ["test", "spec", "behavior"]},
      {~r/test\s+/i, ["test", "assertion"]}
    ]

    matched_keywords =
      patterns
      |> Enum.filter(fn {regex, _} -> Regex.match?(regex, code) end)
      |> Enum.flat_map(fn {_, keywords} -> keywords end)

    # Extract identifiers (function/module names)
    function_keywords = extract_identifiers(code, ~r/def\s+(\w+)/)
    module_keywords = extract_identifiers(code, ~r/defmodule\s+[\w.]*\.(\w+)/)

    (matched_keywords ++ function_keywords ++ module_keywords)
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
  end

  defp extract_gleam_patterns(code) do
    patterns = [
      {~r/import\s+gleam\/otp\/actor/i, ["actor", "process", "concurrent", "otp"]},
      {~r/import\s+gleam\/otp\/supervisor/i, ["supervisor", "fault_tolerance", "otp"]},
      {~r/import\s+gleam\/http/i, ["http", "client", "api"]},
      {~r/import\s+gleam\/json/i, ["json", "serialization", "encoding"]},
      {~r/type\s+Message/i, ["message", "protocol", "type_safety"]},
      {~r/pub\s+fn\s+handle/i, ["handler", "callback", "event"]}
    ]

    matched_keywords =
      patterns
      |> Enum.filter(fn {regex, _} -> Regex.match?(regex, code) end)
      |> Enum.flat_map(fn {_, keywords} -> keywords end)

    function_keywords = extract_identifiers(code, ~r/pub\s+fn\s+(\w+)/)
    type_keywords = extract_identifiers(code, ~r/type\s+(\w+)/)

    (matched_keywords ++ function_keywords ++ type_keywords)
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
  end

  defp extract_rust_patterns(code) do
    patterns = [
      {~r/use\s+tokio/i, ["async", "runtime", "concurrent", "tokio"]},
      {~r/async\s+fn/i, ["async", "concurrent", "await"]},
      {~r/use\s+serde/i, ["serialization", "json", "encoding"]},
      {~r/use\s+async_nats/i, ["nats", "messaging", "async"]},
      {~r/#\[derive\(.*Serialize/i, ["serialization", "json", "derive"]},
      {~r/impl.*Service/i, ["service", "trait", "interface"]},
      {~r/\.await/i, ["async", "future", "concurrent"]}
    ]

    matched_keywords =
      patterns
      |> Enum.filter(fn {regex, _} -> Regex.match?(regex, code) end)
      |> Enum.flat_map(fn {_, keywords} -> keywords end)

    struct_keywords = extract_identifiers(code, ~r/struct\s+(\w+)/)
    impl_keywords = extract_identifiers(code, ~r/impl.*?(\w+)/)

    (matched_keywords ++ struct_keywords ++ impl_keywords)
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
  end

  defp extract_identifiers(code, regex) do
    regex
    |> Regex.scan(code)
    |> Enum.map(fn [_, id] -> id end)
    |> Enum.flat_map(&extract_from_text/1)
  end
end
