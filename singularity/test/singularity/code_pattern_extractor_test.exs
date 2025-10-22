defmodule Singularity.CodePatternExtractorTest do
  use ExUnit.Case, async: true
  alias Singularity.CodePatternExtractor

  describe "extract_from_text/1" do
    test "basic extraction" do
      assert CodePatternExtractor.extract_from_text("Create an API client") == [
               "create",
               "api",
               "client"
             ]
    end

    test "removes stop words" do
      tokens = CodePatternExtractor.extract_from_text("the user is authenticated")
      assert "the" not in tokens
      assert "is" not in tokens
      assert "user" in tokens
      assert "authenticated" in tokens
    end

    test "splits camelCase" do
      assert CodePatternExtractor.extract_from_text("apiClient") == ["api", "client"]
      assert CodePatternExtractor.extract_from_text("GenServer") == ["gen", "server"]
    end

    test "splits snake_case" do
      assert CodePatternExtractor.extract_from_text("api_client") == ["api", "client"]
    end

    test "handles punctuation" do
      tokens = CodePatternExtractor.extract_from_text("Create API client, with auth!")
      assert tokens == ["create", "api", "client", "auth"]
    end
  end

  describe "find_matching_patterns/2" do
    test "exact keyword match scores highest" do
      patterns = [
        %{name: "api_client", keywords: ["api", "client", "http"]},
        %{name: "database", keywords: ["database", "sql", "query"]},
        %{name: "nats_consumer", keywords: ["nats", "consumer", "message"]}
      ]

      user_tokens = ["nats", "consumer"]
      matches = CodePatternExtractor.find_matching_patterns(user_tokens, patterns)

      assert [%{pattern: %{name: "nats_consumer"}} | _] = matches
    end

    test "pattern name contributes to score" do
      patterns = [
        %{name: "HTTP Client", keywords: ["request"]},
        %{name: "database", keywords: ["storage"]}
      ]

      user_tokens = ["http", "client"]
      matches = CodePatternExtractor.find_matching_patterns(user_tokens, patterns)

      assert [%{pattern: %{name: "HTTP Client"}} | _] = matches
    end

    test "relationship bonus increases score" do
      patterns = [
        %{
          name: "nats_service",
          keywords: ["nats"],
          relationships: ["genserver", "supervisor"]
        },
        %{name: "simple_nats", keywords: ["nats"]}
      ]

      # User mentions related pattern
      user_tokens = ["nats", "genserver"]
      matches = CodePatternExtractor.find_matching_patterns(user_tokens, patterns)

      # Pattern with relationship should score higher
      assert [%{pattern: %{name: "nats_service"}} | _] = matches
    end

    test "no match returns empty list" do
      patterns = [
        %{name: "database", keywords: ["sql", "query"]}
      ]

      user_tokens = ["http", "api"]
      matches = CodePatternExtractor.find_matching_patterns(user_tokens, patterns)

      assert matches == []
    end
  end

  describe "extract_from_code/2 - Elixir" do
    test "detects GenServer pattern" do
      code = """
      defmodule MyWorker do
        use GenServer

        def init(_), do: {:ok, %{}}

        def handle_call(:work, _from, state) do
          {:reply, :ok, state}
        end
      end
      """

      tokens = CodePatternExtractor.extract_from_code(code, :elixir)

      assert "genserver" in tokens
      assert "state" in tokens
      assert "handle_call" in tokens or "synchronous" in tokens
    end

    test "detects NATS pattern" do
      code = """
      defmodule Consumer do
        def start do
          {:ok, conn} = Gnat.start_link()
          Gnat.sub(conn, self(), "events.>")
        end
      end
      """

      tokens = CodePatternExtractor.extract_from_code(code, :elixir)

      assert "nats" in tokens
      assert "messaging" in tokens
    end

    test "detects Broadway pattern" do
      code = """
      defmodule Pipeline do
        use Broadway

        def handle_message(_, message, _) do
          message
        end
      end
      """

      tokens = CodePatternExtractor.extract_from_code(code, :elixir)

      assert "broadway" in tokens
      assert "pipeline" in tokens
    end

    test "extracts module and function names" do
      code = """
      defmodule MyApp.UserService do
        def authenticate(user) do
          :ok
        end
      end
      """

      tokens = CodePatternExtractor.extract_from_code(code, :elixir)

      assert "user" in tokens or "userservice" in tokens
      assert "authenticate" in tokens
    end
  end

  describe "extract_from_code/2 - Gleam" do
    test "detects actor pattern" do
      code = """
      import gleam/otp/actor

      pub fn start() {
        actor.start(init, handle_message)
      }
      """

      tokens = CodePatternExtractor.extract_from_code(code, :gleam)

      assert "actor" in tokens
      assert "process" in tokens
    end

    test "detects supervisor pattern" do
      code = """
      import gleam/otp/supervisor

      pub fn init() {
        supervisor.start(children)
      }
      """

      tokens = CodePatternExtractor.extract_from_code(code, :gleam)

      assert "supervisor" in tokens
    end
  end

  describe "extract_from_code/2 - Rust" do
    test "detects async pattern" do
      code = """
      use tokio;

      async fn process() {
        // work
      }
      """

      tokens = CodePatternExtractor.extract_from_code(code, :rust)

      assert "async" in tokens
      assert "runtime" in tokens
    end

    test "detects serialization pattern" do
      code = """
      use serde::{Serialize, Deserialize};

      #[derive(Serialize, Deserialize)]
      struct User {
        name: String
      }
      """

      tokens = CodePatternExtractor.extract_from_code(code, :rust)

      assert "serialization" in tokens
      assert "json" in tokens
    end
  end
end
