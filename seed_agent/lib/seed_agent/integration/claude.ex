defmodule SeedAgent.Integration.Claude do
  @moduledoc """
  Claude Code CLI integration using long-lived OAuth tokens.

  We shell out to the Claude Code CLI (`claude chat --print --output-format json`).
  Authentication relies on the same token sources as the CLI:

    * `opts[:oauth_token]`
    * `CLAUDE_CODE_OAUTH_TOKEN`
    * the cached credentials JSON under `CLAUDE_HOME` or `~/.claude`

  Mount the `.claude` directory (or set `CLAUDE_HOME`) on Fly if you want automatic
  token refresh. CLI flags can be injected via `CLAUDE_CLI_FLAGS` or `opts[:claude_flags]`.
  """

  require Logger

  @default_cli "claude"
  @default_model "sonnet"
  @default_timeout :timer.minutes(2)
  @max_prompt_length 100_000
  @max_messages 100

  @spec chat(String.t() | list(), keyword()) :: {:ok, map()} | {:error, term()}
  def chat(prompt_or_messages, opts \\ []) do
    messages = normalize_messages(prompt_or_messages)

    with :ok <- validate_messages(messages),
         {:ok, cli} <- ensure_cli(opts),
         {:ok, prompt} <- build_prompt(messages),
         env <- build_env(opts),
         args <- build_args(prompt, opts),
         {output, status} <- System.cmd(cli, args, cli_options(env, opts)),
         {:ok, payload} <- handle_cli_result(output, status) do
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
    base = ["chat", "--print", "--output-format", "json"]

    (base
    |> maybe_append(["--model", opts[:model] || default_model()])
    |> maybe_append(cli_flags(opts))) ++ [prompt]
  end

  defp cli_flags(opts) do
    opts[:claude_flags] || Application.get_env(:seed_agent, :claude)[:cli_flags] || []
  end

  defp cli_options(env, opts) do
    timeout = opts[:timeout] || @default_timeout

    [
      env: env,
      stderr_to_stdout: true,
      timeout: timeout,
      into: opts[:into]
    ]
    |> Enum.reject(fn {k, v} -> k == :into and is_nil(v) end)
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

  defp handle_cli_result(output, 0) do
    case Jason.decode(output) do
      {:ok, decoded} -> {:ok, %{raw: output, response: decoded}}
      {:error, _} -> {:ok, %{raw: output}}
    end
  end

  defp handle_cli_result(output, status), do: {:error, {:cli_failure, status, output}}

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
end
