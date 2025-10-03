defmodule SeedAgent.Integration.Claude do
  @moduledoc """
  Claude Code CLI integration - EMERGENCY RECOVERY.

  This is our backup/recovery integration when the HTTP AI server is unavailable.
  We shell out to the Claude recovery CLI (`claude-recovery chat --print --output-format json`).

  ## Recovery CLI Location

  The Claude recovery binary is installed to a dedicated location:
    * Binary name: `claude-recovery` (avoids collision with NPM SDK)
    * Default path: `~/.singularity/emergency/bin/claude-recovery`
    * Custom: Set `SINGULARITY_EMERGENCY_BIN` env var
    * Install: `./scripts/install_claude_native.sh`
    * Allows dangerous flags for recovery scenarios

  ## Authentication

  Authentication relies on the same token sources as the CLI:
    * `opts[:oauth_token]`
    * `CLAUDE_CODE_OAUTH_TOKEN`
    * the cached credentials JSON under `CLAUDE_HOME` or `~/.claude`

  Mount the `.claude` directory (or set `CLAUDE_HOME`) on Fly if you want automatic
  token refresh. CLI flags can be injected via `CLAUDE_CLI_FLAGS` or `opts[:claude_flags]`.

  ## Usage Priority

  1. Primary: Use `Singularity.AIProvider` (HTTP to ai-server)
  2. Fallback: Use this module directly when HTTP server is down
  """

  require Logger

  @default_cli "claude-recovery"
  @default_model "sonnet"
  @default_timeout :timer.minutes(2)
  @max_prompt_length 100_000
  @max_messages 100

  @doc """
  Send a chat request and get the full response.

  ## Options
    * `:model` - Model to use (default: "sonnet")
    * `:stream` - If true, returns streaming response (default: false)
    * `:dangerous_mode` - Skip all permissions for emergency recovery (default: false)
    * `:allowed_tools` - List of allowed tools (e.g., ["Bash", "Edit"])
    * `:disallowed_tools` - List of disallowed tools
    * `:timeout` - Timeout in milliseconds (default: 2 minutes)
    * `:oauth_token` - OAuth token override
    * `:claude_flags` - Additional CLI flags

  ## Examples

      # Simple chat
      {:ok, response} = Claude.chat("What is 2+2?")

      # With streaming callback
      {:ok, full_text} = Claude.chat("Write a poem", stream: fn chunk ->
        IO.write(chunk)
      end)

      # Emergency recovery mode (skips permissions)
      {:ok, response} = Claude.chat("Fix the system", dangerous_mode: true)
  """
  @spec chat(String.t() | list(), keyword()) :: {:ok, map()} | {:error, term()}
  def chat(prompt_or_messages, opts \\ []) do
    messages = normalize_messages(prompt_or_messages)

    with :ok <- validate_messages(messages),
         {:ok, cli} <- ensure_cli(opts),
         {:ok, prompt} <- build_prompt(messages),
         env <- build_env(opts),
         args <- build_args(prompt, opts),
         {output, status} <- run_cli(cli, args, env, opts),
         {:ok, payload} <- handle_cli_result(output, status, opts) do
      {:ok, payload}
    else
      {:error, reason} -> {:error, reason}
      {_, status} -> {:error, {:cli_exit_status, status}}
    end
  end

  defp normalize_messages(prompt) when is_binary(prompt) do
    [
      %{
        role: "user",
        content: [%{type: "text", text: prompt}]
      }
    ]
  end

  defp normalize_messages(messages) when is_list(messages), do: messages

  defp ensure_cli(opts) do
    cli = opts[:cli_path] || cli_path_from_config() || @default_cli

    case System.find_executable(cli) do
      nil -> {:error, {:cli_not_found, cli}}
      _ -> {:ok, cli}
    end
  end

  defp cli_path_from_config do
    Application.get_env(:seed_agent, :claude)[:cli_path] || System.get_env("CLAUDE_CLI_PATH")
  end

  defp build_prompt(messages) when is_list(messages) do
    prompt =
      messages
      |> Enum.map(&message_to_text/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    if prompt == "" do
      {:error, :empty_prompt}
    else
      {:ok, prompt}
    end
  end

  defp message_to_text(%{role: "user", content: content}), do: extract_text(content)
  defp message_to_text(%{"role" => "user", "content" => content}), do: extract_text(content)
  defp message_to_text(binary) when is_binary(binary), do: binary
  defp message_to_text(_), do: nil

  defp extract_text(content) when is_binary(content), do: content

  defp extract_text(content) when is_list(content) do
    content
    |> Enum.map(fn
      %{text: text} -> text
      %{"text" => text} -> text
      %{type: "text", text: text} -> text
      %{"type" => "text", "text" => text} -> text
      other -> inspect(other)
    end)
    |> Enum.join("\n\n")
  end

  defp extract_text(_), do: nil

  defp build_args(prompt, opts) do
    # Use stream-json for better streaming support
    output_format = if opts[:stream], do: "stream-json", else: "json"

    base = [
      "chat",
      "--print",
      "--output-format", output_format
    ]

    base
    |> maybe_append(["--model", opts[:model] || default_model()])
    |> maybe_append_flag(opts[:dangerous_mode], "--dangerously-skip-permissions")
    |> maybe_append_flag(opts[:stream], "--include-partial-messages")
    |> maybe_append_tools("--allowed-tools", opts[:allowed_tools])
    |> maybe_append_tools("--disallowed-tools", opts[:disallowed_tools])
    |> maybe_append(cli_flags(opts))
    |> Kernel.++([prompt])
  end

  defp maybe_append_flag(list, true, flag), do: list ++ [flag]
  defp maybe_append_flag(list, _, _flag), do: list

  defp maybe_append_tools(list, _flag, nil), do: list
  defp maybe_append_tools(list, _flag, []), do: list
  defp maybe_append_tools(list, flag, tools) when is_list(tools) do
    list ++ [flag, Enum.join(tools, ",")]
  end

  defp cli_flags(opts) do
    opts[:claude_flags] || Application.get_env(:seed_agent, :claude)[:cli_flags] || []
  end

  defp run_cli(cli, args, env, opts) do
    timeout = opts[:timeout] || @default_timeout
    stream_callback = if is_function(opts[:stream], 1), do: opts[:stream], else: nil

    cli_opts = [
      env: env,
      stderr_to_stdout: true,
      timeout: timeout
    ]

    if stream_callback do
      # Stream mode: collect output while calling callback for each chunk
      collector = __MODULE__.StreamCollector.new(stream_callback)

      cli_opts = cli_opts ++ [into: collector]
      {final_output, status} = System.cmd(cli, args, cli_opts)

      {final_output, status}
    else
      # Non-stream mode: simple command execution
      System.cmd(cli, args, cli_opts)
    end
  end

  defp validate_messages(messages) when is_list(messages) do
    cond do
      length(messages) > @max_messages ->
        {:error, {:too_many_messages, @max_messages}}

      Enum.any?(messages, &exceeds_max_length?/1) ->
        {:error, {:message_too_long, @max_prompt_length}}

      true ->
        :ok
    end
  end

  defp exceeds_max_length?(%{content: content}) when is_binary(content) do
    String.length(content) > @max_prompt_length
  end

  defp exceeds_max_length?(%{"content" => content}) when is_binary(content) do
    String.length(content) > @max_prompt_length
  end

  defp exceeds_max_length?(_), do: false

  defp handle_cli_result(output, 0, opts) do
    if opts[:stream] do
      # For stream mode, output might be a collection of JSON lines
      # Return the raw output and let streaming callback handle it
      {:ok, %{raw: output, streamed: true}}
    else
      # For non-stream mode, parse single JSON response
      case Jason.decode(output) do
        {:ok, decoded} -> {:ok, %{raw: output, response: decoded}}
        {:error, _} -> {:ok, %{raw: output}}
      end
    end
  end

  defp handle_cli_result(output, status, _opts), do: {:error, {:cli_failure, status, output}}

  defp build_env(opts) do
    token =
      opts[:oauth_token] ||
        System.get_env("CLAUDE_CODE_OAUTH_TOKEN") ||
        credentials_token()

    %{}
    |> maybe_put("CLAUDE_CODE_OAUTH_TOKEN", token)
    |> maybe_put("CLAUDE_TELEMETRY_OPTOUT", "1")
    |> maybe_put("CLAUDE_NO_COLOR", "1")
    |> maybe_put("CLAUDE_HOME", custom_home())
    |> Map.to_list()
  end

  defp credentials_token do
    with {:ok, path} <- credentials_path(),
         {:ok, body} <- File.read(path),
         {:ok, json} <- Jason.decode(body),
         token when is_binary(token) <- get_in(json, ["claudeAiOauth", "accessToken"]),
         {:ok, expires_at} <- parse_timestamp(get_in(json, ["claudeAiOauth", "expiresAt"])),
         false <- expired?(expires_at) do
      token
    else
      _ -> nil
    end
  end

  defp credentials_path do
    claude_home = custom_home() || Path.join(System.user_home!(), ".claude")
    path = Path.join(claude_home, ".credentials.json")

    if File.exists?(path), do: {:ok, path}, else: {:error, :missing_credentials}
  rescue
    _ -> {:error, :missing_credentials}
  end

  defp custom_home do
    System.get_env("CLAUDE_HOME") || Application.get_env(:seed_agent, :claude)[:home]
  end

  defp parse_timestamp(nil), do: {:error, :no_timestamp}
  defp parse_timestamp(timestamp) when is_integer(timestamp), do: {:ok, timestamp}

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _} -> {:ok, DateTime.to_unix(datetime)}
      _ -> {:error, :invalid_timestamp}
    end
  end

  defp parse_timestamp(_), do: {:error, :invalid_timestamp}

  defp expired?(timestamp) do
    case timestamp do
      nil -> false
      unix when is_integer(unix) -> DateTime.to_unix(DateTime.utc_now()) >= unix
      _ -> false
    end
  end

  defp maybe_append(list, []), do: list
  defp maybe_append(list, nil), do: list
  defp maybe_append(list, values), do: list ++ values

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp default_model do
    Application.get_env(:seed_agent, :claude)[:default_model] || @default_model
  end

  # StreamCollector: Implements IO.write protocol for streaming CLI output
  defmodule StreamCollector do
    @moduledoc false

    defstruct [:callback, :buffer]

    def new(callback) when is_function(callback, 1) do
      %__MODULE__{callback: callback, buffer: ""}
    end

    defimpl Collectable do
      def into(collector) do
        {collector,
         fn
           acc, {:cont, data} ->
             # Process streaming JSON lines
             process_chunk(acc, data)

           acc, :done ->
             acc

           _acc, :halt ->
             :ok
         end}
      end

      defp process_chunk(%{callback: callback, buffer: buffer} = acc, data) when is_binary(data) do
        # Accumulate data and process complete JSON lines
        new_buffer = buffer <> data
        {complete_lines, remaining} = split_json_lines(new_buffer)

        # Parse and emit each complete JSON line with robust error handling
        Enum.each(complete_lines, fn line ->
          # Skip empty lines
          if String.trim(line) != "" do
            case Jason.decode(line) do
              {:ok, %{"type" => "content_block_delta", "delta" => %{"text" => text}}} ->
                callback.(text)

              {:ok, %{"type" => "message_delta", "delta" => %{"text" => text}}} ->
                callback.(text)

              {:ok, %{"text" => text}} when is_binary(text) ->
                callback.(text)

              {:ok, _other} ->
                # Ignore non-text events (metadata, etc.)
                :ok

              {:error, %Jason.DecodeError{}} ->
                # Ignore malformed JSON (common with streaming LLM partial responses)
                # The buffer accumulation will handle incomplete lines
                :ok
            end
          end
        end)

        %{acc | buffer: remaining}
      end

      defp split_json_lines(data) do
        lines = String.split(data, "\n")
        ends_with_newline = String.ends_with?(data, "\n")

        case List.pop_at(lines, -1) do
          {last, rest} when byte_size(last) > 0 ->
            if ends_with_newline do
              # All lines are complete
              {lines, ""}
            else
              # Last line is incomplete
              {rest, last}
            end

          {_last, rest} ->
            # All lines are complete (empty last element)
            {rest, ""}
        end
      end
    end
  end
end
