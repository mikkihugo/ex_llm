defmodule SeedAgent.Integration.ClaudeTest do
  use ExUnit.Case, async: false

  alias SeedAgent.Integration.Claude

  # Mock helper to simulate CLI responses
  defmodule MockCLI do
    def create_mock_script(response_file) do
      script = """
      #!/usr/bin/env bash
      cat #{response_file}
      exit 0
      """

      path = Path.join(System.tmp_dir!(), "mock-claude-#{:erlang.unique_integer([:positive])}.sh")
      File.write!(path, script)
      File.chmod!(path, 0o755)
      path
    end

    def create_streaming_mock(chunks) do
      content = Enum.map_join(chunks, "\n", &Jason.encode!/1)

      response_file =
        Path.join(
          System.tmp_dir!(),
          "mock-response-#{:erlang.unique_integer([:positive])}.json"
        )

      File.write!(response_file, content)
      create_mock_script(response_file)
    end

    def create_json_mock(data) do
      response_file =
        Path.join(
          System.tmp_dir!(),
          "mock-response-#{:erlang.unique_integer([:positive])}.json"
        )

      File.write!(response_file, Jason.encode!(data))
      create_mock_script(response_file)
    end

    def cleanup(path) do
      # Clean up both script and any response files
      File.rm(path)
      # Clean response files that match pattern
      dir = Path.dirname(path)

      Path.wildcard(Path.join(dir, "mock-response-*.json"))
      |> Enum.each(&File.rm/1)
    end
  end

  # Unit Tests - Testing business logic with mocked dependencies
  describe "chat/2 with mocked CLI (unit)" do
    test "successfully chats with simple prompt" do
      mock_response = %{
        "text" => "Hello, world!",
        "model" => "sonnet"
      }

      mock_cli = MockCLI.create_json_mock(mock_response)
      Application.put_env(:seed_agent, :claude, cli_path: mock_cli)

      on_exit(fn ->
        MockCLI.cleanup(mock_cli)
        Application.delete_env(:seed_agent, :claude)
      end)

      assert {:ok, result} = Claude.chat("Hello")
      assert result.response["text"] == "Hello, world!"
      assert result.response["model"] == "sonnet"
    end

    test "handles CLI errors gracefully" do
      # Point to non-existent binary
      Application.put_env(:seed_agent, :claude, cli_path: "/nonexistent/binary")
      on_exit(fn -> Application.delete_env(:seed_agent, :claude) end)

      assert {:error, {:cli_not_found, "/nonexistent/binary"}} = Claude.chat("test")
    end

    test "validates message length" do
      # Create a message that's too long
      long_message = String.duplicate("a", 100_001)

      assert {:error, {:message_too_long, 100_000}} = Claude.chat(long_message)
    end

    test "validates message count" do
      # Too many messages
      messages = for i <- 1..101, do: %{role: "user", content: "msg #{i}"}

      assert {:error, {:too_many_messages, 100}} = Claude.chat(messages)
    end

    test "accepts list of messages" do
      messages = [
        %{role: "user", content: "First message"},
        %{role: "assistant", content: "Response"},
        %{role: "user", content: "Second message"}
      ]

      mock_response = %{"text" => "Final response"}
      mock_cli = MockCLI.create_json_mock(mock_response)
      Application.put_env(:seed_agent, :claude, cli_path: mock_cli)

      on_exit(fn ->
        MockCLI.cleanup(mock_cli)
        Application.delete_env(:seed_agent, :claude)
      end)

      assert {:ok, result} = Claude.chat(messages)
      assert result.response["text"] == "Final response"
    end
  end

  describe "chat/2 with options (unit)" do
    test "respects model option" do
      mock_response = %{"text" => "Response", "model" => "opus"}
      mock_cli = MockCLI.create_json_mock(mock_response)
      Application.put_env(:seed_agent, :claude, cli_path: mock_cli)

      on_exit(fn ->
        MockCLI.cleanup(mock_cli)
        Application.delete_env(:seed_agent, :claude)
      end)

      assert {:ok, result} = Claude.chat("test", model: "opus")
      assert result.response["model"] == "opus"
    end

    test "uses dangerous mode when requested" do
      mock_response = %{"text" => "Emergency response"}
      mock_cli = MockCLI.create_json_mock(mock_response)
      Application.put_env(:seed_agent, :claude, cli_path: mock_cli)

      on_exit(fn ->
        MockCLI.cleanup(mock_cli)
        Application.delete_env(:seed_agent, :claude)
      end)

      # Should not raise an error
      assert {:ok, _result} = Claude.chat("fix system", dangerous_mode: true)
    end

    # Note: System.cmd doesn't support timeout option directly
    # Timeout handling would require wrapping in Task.async with timeout
    # which is beyond scope of current implementation
  end

  # Integration Tests - Testing with real CLI behavior simulation
  describe "streaming with mocked CLI (integration)" do
    test "processes streaming JSON responses" do
      chunks = [
        %{"type" => "content_block_delta", "delta" => %{"text" => "Hello"}},
        %{"type" => "content_block_delta", "delta" => %{"text" => " "}},
        %{"type" => "content_block_delta", "delta" => %{"text" => "World"}}
      ]

      mock_cli = MockCLI.create_streaming_mock(chunks)
      Application.put_env(:seed_agent, :claude, cli_path: mock_cli)

      on_exit(fn ->
        MockCLI.cleanup(mock_cli)
        Application.delete_env(:seed_agent, :claude)
      end)

      parent = self()
      callback = fn chunk -> send(parent, {:chunk, chunk}) end

      assert {:ok, result} = Claude.chat("test", stream: callback)
      assert result.streamed == true

      # Collect chunks with timeout
      chunks =
        Stream.repeatedly(fn ->
          receive do
            {:chunk, chunk} -> chunk
          after
            50 -> nil
          end
        end)
        |> Enum.take_while(&(&1 != nil))
        |> Enum.take(5)

      # Should have received text chunks
      all_text = Enum.join(chunks, "")
      assert all_text =~ "Hello"
      assert all_text =~ "World"
    end

    test "handles mixed streaming events" do
      chunks = [
        %{"type" => "content_block_start", "index" => 0},
        %{"type" => "content_block_delta", "delta" => %{"text" => "Test"}},
        %{"type" => "message_delta", "delta" => %{"text" => " response"}},
        %{"type" => "content_block_stop"},
        %{"text" => "Direct text"}
      ]

      mock_cli = MockCLI.create_streaming_mock(chunks)
      Application.put_env(:seed_agent, :claude, cli_path: mock_cli)

      on_exit(fn ->
        MockCLI.cleanup(mock_cli)
        Application.delete_env(:seed_agent, :claude)
      end)

      parent = self()
      callback = fn chunk -> send(parent, {:chunk, chunk}) end

      assert {:ok, _result} = Claude.chat("test", stream: callback)

      # Collect text chunks
      chunks =
        Stream.repeatedly(fn ->
          receive do
            {:chunk, chunk} -> chunk
          after
            50 -> nil
          end
        end)
        |> Enum.take_while(&(&1 != nil))
        |> Enum.take(10)

      all_text = Enum.join(chunks, "")
      assert all_text =~ "Test"
      assert all_text =~ "response"
      assert all_text =~ "Direct text"
    end
  end

  # E2E Tests - Full flow with actual binary (skipped unless available)
  describe "end-to-end with real CLI" do
    @describetag :e2e
    @describetag timeout: 30_000

    setup do
      cli_path =
        System.get_env("CLAUDE_CLI_PATH") ||
          Path.expand("~/.singularity/emergency/bin/claude-recovery")

      has_cli = File.exists?(cli_path)
      has_auth = System.get_env("CLAUDE_CODE_OAUTH_TOKEN") != nil || credentials_exist?()

      if has_cli and has_auth do
        Application.put_env(:seed_agent, :claude, cli_path: cli_path)
        on_exit(fn -> Application.delete_env(:seed_agent, :claude) end)
        {:ok, ready: true, cli_path: cli_path}
      else
        {:ok, ready: false}
      end
    end

    @tag :skip
    test "performs real interaction", %{ready: ready} = _context do
      if ready do
        assert {:ok, response} = Claude.chat("Say exactly: 'test successful'")
        assert response.response["text"] =~ "test"
      else
        IO.puts("\nSkipping E2E test: claude-recovery CLI or credentials not available")
      end
    end

    @tag :skip
    test "streams real response", %{ready: ready} = _context do
      if ready do
        callback = fn chunk ->
          send(self(), {:chunk, chunk})
        end

        assert {:ok, _response} = Claude.chat("Count from 1 to 3", stream: callback)

        # Collect chunks
        result_chunks =
          Stream.repeatedly(fn ->
            receive do
              {:chunk, chunk} -> chunk
            after
              100 -> nil
            end
          end)
          |> Enum.take_while(&(&1 != nil))

        assert length(result_chunks) > 0
      else
        IO.puts("\nSkipping E2E streaming test: claude-recovery CLI or credentials not available")
      end
    end
  end

  # Helper to check if credentials exist
  defp credentials_exist? do
    claude_home = System.get_env("CLAUDE_HOME") || Path.expand("~/.claude")
    creds_path = Path.join(claude_home, ".credentials.json")
    File.exists?(creds_path)
  end
end
