defmodule ExLLM.Providers.Codex do
  @moduledoc """
  OpenAI Codex CLI Provider for ExLLM.

  Integrates with OpenAI's Codex CLI tool, which stores OAuth2 credentials in `~/.codex/auth.json`.
  This provider acts as a bridge to use Codex-authenticated LLM access from ExLLM.

  ## Supported APIs

  ### Chat API (Streaming)
  For real-time chat completions with streaming responses.

      iex> {:ok, response} = ExLLM.Providers.Codex.chat([
      ...>   %{role: "user", content: "Write a binary search function"}
      ...> ])

  ### Task API (Long-running)
  For code generation tasks using the WHAM protocol.

      iex> {:ok, task_id} = ExLLM.Providers.Codex.create_task(
      ...>   environment_id: "owner/repo",
      ...>   branch: "main",
      ...>   prompt: "Add dark mode support"
      ...> )
      iex> {:ok, response} = ExLLM.Providers.Codex.poll_task(task_id)

  ## Credential Management

  TokenManager automatically:
  - Loads credentials from `~/.codex/auth.json` (Codex CLI credentials) first
  - Falls back to local `.codex_oauth_token` cache if needed
  - Extracts token expiration from JWT `exp` claim
  - Auto-refreshes tokens 60 seconds before expiration
  - Syncs refreshed tokens back to `~/.codex/auth.json`

  ## Authentication Flow

  1. User authenticates with Codex CLI: `codex auth`
  2. Credentials stored in `~/.codex/auth.json`
  3. ExLLM loads and uses these same credentials
  4. Tokens auto-refresh and stay in sync with Codex CLI

  ## Available Models

  - `gpt-5-codex` (default) - Specialized code generation (272K context)
  - `gpt-5` - General-purpose reasoning (400K context)
  - `codex-mini-latest` - Fast lightweight model (200K context)

  All models are **FREE** to use with Codex CLI subscription.

  ## Requirements

  - Codex CLI must be authenticated: `npm install -g @openai/codex && codex auth`
  - `~/.codex/auth.json` will be created with valid OpenAI OAuth2 tokens
  """

  @behaviour ExLLM.Provider

  require Logger
  alias ExLLM.Providers.Codex.TokenManager
  alias ExLLM.Providers.Shared.HTTP.Core
  alias ExLLM.Types

  @codex_api_base "https://chatgpt.com/backend-api"
  @codex_chat_endpoint "/conversation"

  @impl true
  def chat(messages, opts \\ []) do
    with {:ok, token} <- TokenManager.get_token(),
         {:ok, response} <- call_api(messages, token, opts) do
      content = extract_content_from_response(response)

      {:ok,
       %ExLLM.Types.LLMResponse{
         content: content,
         model: Map.get(response, "model", "gpt-5-codex"),
         usage: extract_tokens(response),
         cost: 0.0,
         metadata: %{raw_response: response}
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def stream_chat(messages, opts \\ []) do
    with {:ok, token} <- TokenManager.get_token() do
      call_api_stream(messages, token, opts)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def configured?(_opts \\ []) do
    case TokenManager.get_token() do
      {:ok, _token} -> true
      {:error, _} -> false
    end
  end

  @impl true
  def default_model() do
    "gpt-5-codex"
  end

  @impl true
  def list_models(_opts \\ []) do
    # Load models from YAML registry (config/models/codex.yml)
    case load_models_from_registry() do
      {:ok, models} -> {:ok, models}
      {:error, _} -> {:error, "Failed to load Codex models from registry"}
    end
  end

  # Task API Methods (WHAM Protocol)

  @doc """
  Create a new code generation task using the WHAM API.

  ## Options

  - `:environment_id` (required) - Repository identifier (e.g., "owner/repo")
  - `:branch` (required) - Git branch name
  - `:prompt` (required) - Code generation instruction
  - `:model` - Model ID (default: "gpt-5-codex")
  - `:qa_mode` - Run in QA mode (default: false)
  - `:best_of_n` - Number of attempts (default: 1)
  - `:poll_interval_ms` - Polling interval (default: 3000)
  - `:max_attempts` - Max poll attempts (default: 30)
  - `:timeout_ms` - Total timeout (default: 120000)

  ## Returns

  - `{:ok, task_id}` - Task created successfully
  - `{:error, reason}` - Creation failed

  ## Example

      iex> {:ok, task_id} = create_task(
      ...>   environment_id: "mikkihugo/singularity-incubation",
      ...>   branch: "main",
      ...>   prompt: "Add dark mode support to the Phoenix dashboard"
      ...> )
  """
  def create_task(opts) when is_list(opts) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.create_task(opts)
  end

  @doc """
  Create a task and wait for completion (blocking).

  ## Returns

  - `{:ok, task_id, response}` - Task completed with response
  - `{:error, reason}` - Failed

  ## Example

      iex> {:ok, task_id, response} = create_task_and_wait(
      ...>   environment_id: "owner/repo",
      ...>   branch: "main",
      ...>   prompt: "Generate tests",
      ...>   max_attempts: 60
      ...> )
  """
  def create_task_and_wait(opts) when is_list(opts) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.create_task_and_wait(opts)
  end

  @doc """
  Poll a task for completion.

  Continuously polls until completion or timeout.

  ## Options

  - `:poll_interval_ms` - Wait between polls (default: 3000)
  - `:max_attempts` - Maximum polls (default: 30)
  - `:timeout_ms` - Total timeout (default: 120000)

  ## Returns

  - `{:ok, response}` - Task completed
  - `{:error, reason}` - Failed or timed out

  ## Example

      iex> {:ok, response} = poll_task("task_e_...", max_attempts: 60)
  """
  def poll_task(task_id, opts \\ []) when is_binary(task_id) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.poll_task(task_id, opts)
  end

  @doc """
  Get task status without waiting.

  ## Returns

  - `{:ok, status}` - Current status ("queued", "in_progress", "completed", etc.)
  - `{:error, reason}` - Request failed
  """
  def get_task_status(task_id) when is_binary(task_id) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.get_task_status(task_id)
  end

  @doc """
  Get full task response without polling.

  ## Returns

  - `{:ok, response}` - Full WHAM response
  - `{:error, reason}` - Request failed
  """
  def get_task_response(task_id) when is_binary(task_id) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.get_task_response(task_id)
  end

  @doc """
  Extract structured data from a task response.

  ## Returns

  Map with extracted message, code_diff, pr_info, and files.

  ## Example

      iex> {:ok, response} = get_task_response(task_id)
      iex> extracted = extract_response(response)
      iex> extracted.code_diff
      "diff --git a/lib/..."
  """
  def extract_response(response) when is_map(response) do
    alias ExLLM.Providers.Codex.ResponseExtractor
    ResponseExtractor.extract(response)
  end

  @doc """
  List user's tasks.

  ## Options

  - `:limit` - Number of tasks (default: 10)
  - `:offset` - Pagination offset (default: 0)

  ## Returns

  - `{:ok, tasks}` - List of task summaries
  - `{:error, reason}` - Request failed
  """
  def list_tasks(opts \\ []) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.list_tasks(opts)
  end

  @doc """
  Check rate limit usage.

  ## Returns

  - `{:ok, usage}` - Rate limit information
  - `{:error, reason}` - Request failed

  ## Example Response

      %{
        "primary_window" => %{"used_percent" => 8, ...},
        "secondary_window" => %{"used_percent" => 15, ...}
      }
  """
  def get_usage() do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.get_usage()
  end

  # Private helpers for model loading

  defp load_models_from_registry() do
    config_path = get_config_path()

    case File.read(config_path) do
      {:ok, content} ->
        case YamlElixir.read_from_string(content) do
          {:ok, %{"models" => models}} when is_map(models) ->
            registry_models = build_models_from_registry(models)
            {:ok, registry_models}

          {:ok, _} ->
            Logger.error("Invalid Codex config format: missing 'models' key")
            {:error, "Invalid config format"}

          {:error, reason} ->
            Logger.error("Failed to parse Codex config: #{inspect(reason)}")
            {:error, "Failed to parse config"}
        end

      {:error, reason} ->
        Logger.error("Failed to read Codex config: #{inspect(reason)}")
        {:error, "Config file not found"}
    end
  end

  defp get_config_path() do
    Path.expand("config/models/codex.yml")
  end

  defp build_models_from_registry(models) when is_map(models) do
    Enum.map(models, fn {model_id, config} ->
      %Types.Model{
        id: model_id,
        name: Map.get(config, "name", "Codex #{model_id}"),
        description: Map.get(config, "description", "ChatGPT Pro model #{model_id}"),
        context_window: Map.get(config, "context_window", 128_000),
        max_output_tokens: Map.get(config, "max_output_tokens", 4096),
        pricing: build_pricing(Map.get(config, "pricing", %{})),
        capabilities: Map.get(config, "capabilities", [])
      }
    end)
  end

  defp build_pricing(pricing) when is_map(pricing) do
    %{
      input: pricing["input"] || 0.0,
      output: pricing["output"] || 0.0
    }
  end

  defp build_pricing(_), do: %{input: 0.0, output: 0.0}

  # API communication

  defp call_api(messages, _token, opts) do
    # Use the WHAM Task API instead of simple chat completion
    # This provides the proper Codex format with special input tags
    # Use create_task_and_wait for proper async handling
    task_opts = [
      environment_id: get_environment_id(opts),
      branch: get_branch(opts),
      prompt: format_codex_input(extract_user_content(messages), opts),
      model: Keyword.get(opts, :model, default_model()),
      sandbox_policy: Keyword.get(opts, :sandbox_policy, "workspace-write"),
      approval_policy: Keyword.get(opts, :approval_policy, "untrusted"),
      max_attempts: 60,
      timeout_ms: 300_000
    ]
    
    case create_task_and_wait(task_opts) do
      {:ok, _task_id, response} ->
        # Extract the response content
        extract_response_content(response)
      
      {:error, reason} ->
        {:error, reason}
    end
  end


  defp extract_user_content(messages) when is_list(messages) do
    messages
    |> Enum.find(fn msg -> 
      role = get_role(msg)
      role == "user" || role == "assistant"
    end)
    |> case do
      nil -> "Hello"
      msg -> get_content(msg)
    end
  end

  defp format_codex_input(user_content, opts) do
    # Add special Codex input format tags
    system_prompt = get_system_prompt(opts)
    environment_context = get_environment_context(opts)
    
    """
    <user_instructions>
    #{system_prompt}
    </user_instructions>

    <environment_context>
    #{environment_context}
    </environment_context>

    ## My request for Codex:

    #{user_content}
    """
  end

  defp get_system_prompt(opts) do
    Keyword.get(opts, :system_prompt, """
    You are a coding agent running in the Codex CLI, a terminal-based coding assistant. Codex CLI is an open source project led by OpenAI. You are expected to be precise, safe, and helpful.

    Your capabilities:
    - Receive user prompts and other context provided by the harness, such as files in the workspace.
    - Communicate with the user by streaming thinking & responses, and by making & updating plans.
    - Emit function calls to run terminal commands and apply patches. Depending on how this specific run is configured, you can request that these function calls be escalated to the user for approval before running. More on this in the "Sandbox and approvals" section.

    Within this context, Codex refers to the open-source agentic coding interface (not the old Codex language model built by OpenAI).

    # How you work

    ## Personality

    Your default personality and tone is concise, direct, and friendly. You communicate efficiently, always keeping the user clearly informed about ongoing actions without unnecessary detail. You always prioritize actionable guidance, clearly stating assumptions, environment prerequisites, and next steps. Unless explicitly asked, you avoid excessively verbose explanations about your work.

    # AGENTS.md spec
    - Repos often contain AGENTS.md files. These files can appear anywhere within the repository.
    - These files are a way for humans to give you (the agent) instructions or tips for working within the container.
    - Some examples might be: coding conventions, info about how code is organized, or instructions for how to run or test code.
    - Instructions in AGENTS.md files:
        - The scope of an AGENTS.md file is the entire directory tree rooted at the folder that contains it.
        - For every file you touch in the final patch, you must obey instructions in any AGENTS.md file whose scope includes that file.
        - Instructions about code style, structure, naming, etc. apply only to code within the AGENTS.md file's scope, unless the file states otherwise.
        - More-deeply-nested AGENTS.md files take precedence in the case of conflicting instructions.
        - Direct system/developer/user instructions (as part of a prompt) take precedence over AGENTS.md instructions.
    - The contents of the AGENTS.md file at the root of the repo and any directories from the CWD up to the root are included with the developer message and don't need to be re-read. When working in a subdirectory of CWD, or a directory outside the CWD, check for any AGENTS.md files that may be applicable.

    ## Responsiveness

    ### Preamble messages

    Before making tool calls, send a brief preamble to the user explaining what you're about to do. When sending preamble messages, follow these principles and examples:

    - **Logically group related actions**: if you're about to run several related commands, describe them together in one preamble rather than sending a separate note for each.
    - **Keep it concise**: be no more than 1-2 sentences, focused on immediate, tangible next steps. (8–12 words for quick updates).
    - **Build on prior context**: if this is not your first tool call, use the preamble message to connect the dots with what's been done so far and create a sense of momentum and clarity for the user to understand your next actions.
    - **Keep your tone light, friendly and curious**: add small touches of personality in preambles feel collaborative and engaging.
    - **Exception**: Avoid adding a preamble for every trivial read (e.g., `cat` a single file) unless it's part of a larger grouped action.

    ## Planning

    You have access to an `update_plan` tool which tracks steps and progress and renders them to the user. Using the tool helps demonstrate that you've understood the task and convey how you're approaching it. Plans can help to make complex, ambiguous, or multi-phase work clearer and more collaborative for the user. A good plan should break the task into meaningful, logically ordered steps that are easy to verify as you go.

    Note that plans are not for padding out simple work with filler steps or stating the obvious. The content of your plan should not involve doing anything that you aren't capable of doing (i.e. don't try to test things that you can't test). Do not use plans for simple or single-step queries that you can just do or answer immediately.

    Do not repeat the full contents of the plan after an `update_plan` call — the harness already displays it. Instead, summarize the change made and highlight any important context or next step.

    Before running a command, consider whether or not you have completed the previous step, and make sure to mark it as completed before moving on to the next step. It may be the case that you complete all steps in your plan after a single pass of implementation. If this is the case, you can simply mark all the planned steps as completed. Sometimes, you may need to change plans in the middle of a task: call `update_plan` with the updated plan and make sure to provide an `explanation` of the rationale when doing so.

    Use a plan when:

    - The task is non-trivial and will require multiple actions over a long time horizon.
    - There are logical phases or dependencies where sequencing matters.
    - The work has ambiguity that benefits from outlining high-level goals.
    - You want intermediate checkpoints for feedback and validation.
    - When the user asked you to do more than one thing in a single prompt
    - The user has asked you to use the plan tool (aka "TODOs")
    - You generate additional steps while working, and plan to do them before yielding to the user

    ## Task execution

    You are a coding agent. Please keep going until the query is completely resolved, before ending your turn and yielding back to the user. Only terminate your turn when you are sure that the problem is solved. Autonomously resolve the query to the best of your ability, using the tools available to you, before coming back to the user. Do NOT guess or make up an answer.

    You MUST adhere to the following criteria when solving queries:

    - Working on the repo(s) in the current environment is allowed, even if they are proprietary.
    - Analyzing code for vulnerabilities is allowed.
    - Showing user code and tool call details is allowed.
    - Use the `apply_patch` tool to edit files (NEVER try `applypatch` or `apply-patch`, only `apply_patch`): {"command":["apply_patch","*** Begin Patch\\\\n*** Update File: path/to/file.py\\\\n@@ def example():\\\\n- pass\\\\n+ return 123\\\\n*** End Patch"]}

    If completing the user's task requires writing or modifying files, your code and final answer should follow these coding guidelines, though user instructions (i.e. AGENTS.md) may override these guidelines:

    - Fix the problem at the root cause rather than applying surface-level patches, when possible.
    - Avoid unneeded complexity in your solution.
    - Do not attempt to fix unrelated bugs or broken tests. It is not your responsibility to fix them. (You may mention them to the user in your final message though.)
    - Update documentation as necessary.
    - Keep changes consistent with the style of the existing codebase. Changes should be minimal and focused on the task.
    - Use `git log` and `git blame` to search the history of the codebase if additional context is required.
    - NEVER add copyright or license headers unless specifically requested.
    - Do not waste tokens by re-reading files after calling `apply_patch` on them. The tool call will fail if it didn't work. The same goes for making folders, deleting folders, etc.
    - Do not `git commit` your changes or create new git branches unless explicitly requested.
    - Do not add inline comments within code unless explicitly requested.
    - Do not use one-letter variable names unless explicitly requested.
    """)
  end

  defp get_environment_context(opts) do
    cwd = Keyword.get(opts, :cwd, File.cwd!())
    branch = get_branch(opts)
    
    """
    CWD: #{cwd}
    Git branch: #{branch}
    OS: #{:os.type() |> elem(1) |> to_string()}
    """
  end

  defp get_environment_id(opts) do
    Keyword.get(opts, :environment_id, "singularity-incubation")
  end

  defp get_branch(opts) do
    Keyword.get(opts, :branch, "main")
  end

  defp extract_response_content(response) do
    # Extract content from Codex task response
    case response do
      %{"current_assistant_turn" => %{"output_items" => output_items}} when is_list(output_items) ->
        # Extract text content from output items
        content = output_items
        |> Enum.filter(fn item -> 
          item["type"] == "message" || item["type"] == "text"
        end)
        |> Enum.map(fn item ->
          item["content"] || item["text"] || ""
        end)
        |> Enum.join("\n")
        |> String.trim()
        
        if content != "" do
          {:ok, %{"message" => %{"content" => content}}}
        else
          {:error, "No content found in response"}
        end
      
      %{"current_assistant_turn" => %{"turn_status" => "failed"}} ->
        {:error, "Task failed"}
      
      %{"current_assistant_turn" => %{"turn_status" => "aborted"}} ->
        {:error, "Task aborted"}
      
      _ ->
        {:error, "Unexpected response format: #{inspect(response)}"}
    end
  end

  defp call_api_stream(messages, token, opts) do
    headers = codex_headers(token)

    model = Keyword.get(opts, :model, default_model())
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)

    body = %{
      model: model,
      messages: format_messages(messages),
      temperature: temperature,
      max_tokens: max_tokens,
      stream: true
    }

    client_opts = [
      provider: :codex,
      base_url: @codex_api_base
    ]

    client = Core.client(client_opts)

    case execute_request(client, :post, @codex_chat_endpoint, body, headers) do
      {:ok, stream} when is_function(stream) ->
        stream
        |> Stream.map(&parse_stream_chunk/1)
        |> Stream.each(fn
          {:ok, content} -> Logger.debug("Stream chunk: #{String.length(content)} chars")
          {:error, _} -> :ok
        end)
        |> Stream.run()

        {:ok, "Streaming complete"}

      {:error, reason} ->
        Logger.error("Codex streaming request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Helpers

  defp format_messages(messages) when is_list(messages) do
    Enum.map(messages, fn msg ->
      %{
        role: get_role(msg),
        content: get_content(msg)
      }
    end)
  end

  defp get_role(msg) when is_map(msg) do
    Map.get(msg, :role) || Map.get(msg, "role") || "user"
  end

  defp get_content(msg) when is_map(msg) do
    Map.get(msg, :content) || Map.get(msg, "content") || ""
  end

  defp codex_headers(token) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"},
      {"User-Agent", "ExLLM/1.0.0"}
    ]
  end

  defp execute_request(client, method, path, body, headers) do
    case Tesla.request(client, method: method, url: path, body: body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %Tesla.Env{status: 401}} ->
        Logger.warning("Codex auth failed, token may be expired")
        {:error, "unauthorized"}

      {:ok, %Tesla.Env{status: 429}} ->
        Logger.warning("Codex rate limit exceeded")
        {:error, "rate_limit"}

      {:ok, %Tesla.Env{status: code, body: response_body}} ->
        {:error, "Codex API failed with status #{code}: #{response_body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_stream_chunk(chunk) when is_binary(chunk) do
    case String.split(chunk, "\n") do
      chunks ->
        chunks
        |> Enum.filter(&String.starts_with?(&1, "data: "))
        |> Enum.map(&String.replace_leading(&1, "data: ", ""))
        |> Enum.map(&Jason.decode/1)
        |> Enum.find_value(fn
          {:ok, %{"message" => %{"content" => content}}} -> {:ok, content}
          _ -> nil
        end)
        |> case do
          nil -> {:error, :no_content}
          result -> result
        end
    end
  end

  defp parse_stream_chunk(_chunk), do: {:error, :invalid_chunk}

  defp extract_content_from_response(response) when is_map(response) do
    case response do
      %{"message" => %{"content" => content}} ->
        content

      %{"content" => content} ->
        content

      _ ->
        Logger.warning("Could not extract content from Codex response: #{inspect(response)}")
        ""
    end
  end

  defp extract_tokens(response) when is_map(response) do
    case response do
      %{"usage" => usage} when is_map(usage) ->
        %{
          prompt_tokens: Map.get(usage, "prompt_tokens", 0),
          completion_tokens: Map.get(usage, "completion_tokens", 0),
          total_tokens: Map.get(usage, "total_tokens", 0)
        }

      _ ->
        %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
    end
  end
end
