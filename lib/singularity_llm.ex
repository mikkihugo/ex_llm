defmodule SingularityLLM do
  alias SingularityLLM.Types

  @moduledoc """
  SingularityLLM - A unified Elixir client for Large Language Models.

  SingularityLLM provides a clean, pipeline-based architecture for interacting with various
  LLM providers. The library focuses on two main APIs:

  ## Simple API

  For basic chat completions:

      {:ok, response} = SingularityLLM.chat(:openai, [
        %{role: "user", content: "Hello!"}
      ])
      
      IO.puts(response.content)
      
  ## Advanced API

  For full control over the pipeline:

      import SingularityLLM.Pipeline.Request
      
      request = 
        new(:openai, messages)
        |> assign(:temperature, 0.7)
        |> assign(:max_tokens, 1000)
      
      result = SingularityLLM.run(request, custom_pipeline)
      
  ## Providers

  SingularityLLM supports 14+ providers including:
  - OpenAI (GPT-4, GPT-3.5)
  - Anthropic (Claude)
  - Google (Gemini)
  - Groq
  - Mistral
  - And many more...

  ## Configuration

  Configure providers in your `config.exs`:

      config :singularity_llm, :openai,
        api_key: System.get_env("OPENAI_API_KEY"),
        default_model: "gpt-4"
  """

  alias SingularityLLM.API.Delegator
  alias SingularityLLM.Infrastructure.Logger
  alias SingularityLLM.Pipeline
  alias SingularityLLM.Pipeline.Request
  alias SingularityLLM.Providers

  @doc """
  Sends a chat request to the specified provider.

  This is the simple API for basic use cases. For more control and pipeline
  customization, use the builder API with `build/2` or the advanced `run/2`.

  ## Parameters

    * `provider` - The LLM provider atom (e.g., `:openai`, `:anthropic`)
    * `messages` - List of message maps with `:role` and `:content`
    * `opts` - Optional keyword list of options
    
  ## Options

    * `:model` - Override the default model
    * `:temperature` - Control randomness (0.0 to 2.0)
    * `:max_tokens` - Maximum tokens in response
    * `:stream` - Enable streaming (requires callback function)
    * `:timeout` - Request timeout in milliseconds
    
  ## Examples

      # Simple chat
      {:ok, response} = SingularityLLM.chat(:openai, [
        %{role: "user", content: "Hello!"}
      ])
      
      # With options
      {:ok, response} = SingularityLLM.chat(:anthropic, messages,
        model: "claude-3-opus",
        temperature: 0.5,
        max_tokens: 1000
      )
      
  ## Builder API Alternative

  For pipeline customization, prefer the builder API:
      
      {:ok, response} = 
        SingularityLLM.build(:openai, messages)
        |> SingularityLLM.with_model("gpt-4")
        |> SingularityLLM.with_cache(ttl: 3600)
        |> SingularityLLM.execute()
      
  ## Return Values

  Returns `{:ok, response}` on success where response includes:
    * `:content` - The response text
    * `:role` - The role (usually "assistant")
    * `:model` - The model used
    * `:usage` - Token usage information
    * `:cost` - Calculated cost in USD
    
  Returns `{:error, error}` on failure.
  """
  @spec chat(atom(), list(map()), keyword()) ::
          {:ok, Types.LLMResponse.t() | struct()} | {:error, term()}
  def chat(provider, messages, opts \\ []) do
    case SingularityLLM.Core.Chat.chat(provider, messages, opts) do
      {:ok, %SingularityLLM.Types.LLMResponse{} = response} ->
        # Handle standard LLMResponse - add provider info and normalize fields
        enhanced_response = %{
          response
          | metadata:
              Map.merge(response.metadata || %{}, %{
                provider: provider,
                role: "assistant"
              })
        }

        {:ok, normalize_usage_fields_struct(enhanced_response)}

      {:ok, struct} when is_struct(struct) ->
        # Handle structured output - pass through unchanged
        {:ok, struct}

      result ->
        result
    end
  end

  @doc """
  Sends a streaming chat request to the specified provider.

  Similar to `chat/3` but streams the response in chunks.

  ## Parameters

    * `provider` - The LLM provider atom
    * `messages` - List of message maps
    * `callback` - Function called for each chunk
    * `opts` - Optional keyword list of options
    
  ## Callback Function

  The callback receives chunks with the following structure:
    * `:content` - The text content of this chunk
    * `:done` - Boolean indicating if streaming is complete
    * `:usage` - Token usage (only in final chunk)
    
  ## Examples

      SingularityLLM.stream(:openai, messages, fn
        %{done: true, usage: usage} ->
          IO.puts("\\nTotal tokens: \#{usage.total_tokens}")
          
        %{content: content} ->
          IO.write(content)
      end)
  """
  @spec stream(atom(), list(map()), function(), keyword()) :: :ok | {:error, term()}
  def stream(provider, messages, callback, opts \\ []) when is_function(callback, 1) do
    # Add callback to options and delegate to Core.Chat.stream_chat
    opts_with_callback = Keyword.put(opts, :on_chunk, callback)

    case SingularityLLM.Core.Chat.stream_chat(provider, messages, opts_with_callback) do
      {:ok, stream} ->
        # Consume the stream and trigger callbacks
        try do
          Enum.each(stream, fn chunk ->
            # Invoke the callback for each chunk
            callback.(chunk)
            :ok
          end)

          :ok
        catch
          kind, reason -> {:error, {kind, reason}}
        end

      error ->
        error
    end
  end

  @doc """
  Runs a custom pipeline on a request.

  This is the advanced API that gives you full control over the
  request processing pipeline.

  ## Parameters

    * `request` - An `SingularityLLM.Pipeline.Request` struct
    * `pipeline` - List of plug modules or `{module, opts}` tuples
    
  ## Examples

      # Build custom request
      request = SingularityLLM.Pipeline.Request.new(:openai, messages)
      
      # Define custom pipeline
      pipeline = [
        SingularityLLM.Plugs.ValidateProvider,
        SingularityLLM.Plugs.FetchConfig,
        {SingularityLLM.Plugs.Cache, ttl: 3600},
        MyApp.Plugs.CustomAuth,
        SingularityLLM.Plugs.ExecuteRequest,
        SingularityLLM.Plugs.TrackCost
      ]
      
      # Run it
      result = SingularityLLM.run(request, pipeline)
  """
  @spec run(Request.t(), Pipeline.pipeline()) :: Request.t()
  def run(%Request{} = request, pipeline) when is_list(pipeline) do
    Pipeline.run(request, pipeline)
  end

  ## Chat Builder API Functions

  @doc "Create a new chat builder for enhanced fluent API. See SingularityLLM.ChatBuilder.new/2 for details."
  defdelegate build(provider, messages), to: SingularityLLM.ChatBuilder, as: :new

  @doc "Set the model for a chat builder. See SingularityLLM.ChatBuilder.with_model/2 for details."
  defdelegate with_model(builder, model), to: SingularityLLM.ChatBuilder

  @doc "Sets the temperature for a chat builder. See SingularityLLM.ChatBuilder.with_temperature/2 for details."
  defdelegate with_temperature(builder, temperature), to: SingularityLLM.ChatBuilder

  @doc "Sets the maximum tokens for a chat builder. See SingularityLLM.ChatBuilder.with_max_tokens/2 for details."
  defdelegate with_max_tokens(builder, max_tokens), to: SingularityLLM.ChatBuilder

  @doc "Adds a custom plug to the pipeline. See SingularityLLM.ChatBuilder.with_custom_plug/3 for details."
  defdelegate with_plug(builder, plug, opts \\ []), to: SingularityLLM.ChatBuilder, as: :with_custom_plug

  @doc "Executes a chat builder request. See SingularityLLM.ChatBuilder.execute/1 for details."
  defdelegate execute(builder), to: SingularityLLM.ChatBuilder

  @doc "Streams a chat builder request. See SingularityLLM.ChatBuilder.stream/2 for details."
  defdelegate stream(builder, callback), to: SingularityLLM.ChatBuilder

  ## Enhanced Builder API Methods

  @doc "Enables caching with configurable options on a chat builder. See SingularityLLM.ChatBuilder.with_cache/2 for details."
  defdelegate with_cache(builder, opts \\ []), to: SingularityLLM.ChatBuilder

  @doc "Disables caching for a chat builder request. See SingularityLLM.ChatBuilder.without_cache/1 for details."
  defdelegate without_cache(builder), to: SingularityLLM.ChatBuilder

  @doc "Disables cost tracking for a chat builder request. See SingularityLLM.ChatBuilder.without_cost_tracking/1 for details."
  defdelegate without_cost_tracking(builder), to: SingularityLLM.ChatBuilder

  @doc "Adds a custom plug to the chat builder pipeline. See SingularityLLM.ChatBuilder.with_custom_plug/3 for details."
  defdelegate with_custom_plug(builder, plug, opts \\ []), to: SingularityLLM.ChatBuilder

  @doc "Sets a custom context management strategy for a chat builder. See SingularityLLM.ChatBuilder.with_context_strategy/3 for details."
  defdelegate with_context_strategy(builder, strategy, opts \\ []), to: SingularityLLM.ChatBuilder

  @doc "Returns the pipeline that would be executed without running it. See SingularityLLM.ChatBuilder.inspect_pipeline/1 for details."
  defdelegate inspect_pipeline(builder), to: SingularityLLM.ChatBuilder

  @doc "Returns detailed debugging information about the chat builder state. See SingularityLLM.ChatBuilder.debug_info/1 for details."
  defdelegate debug_info(builder), to: SingularityLLM.ChatBuilder

  # Private helpers

  defp normalize_usage_fields_struct(response) do
    case response.usage do
      %{input_tokens: input, output_tokens: output} = usage ->
        # Add backward compatible fields
        normalized_usage =
          usage
          |> Map.put(:prompt_tokens, input)
          |> Map.put(:completion_tokens, output)
          |> Map.put(:total_tokens, (input || 0) + (output || 0))

        %{response | usage: normalized_usage}

      _ ->
        response
    end
  end

  ## Legacy API Support

  @doc false
  @deprecated "Use SingularityLLM.stream/4 instead"
  def stream_chat(provider, messages, opts \\ []) do
    Logger.warning("SingularityLLM.stream_chat/3 is deprecated. Use SingularityLLM.stream/4 instead.")

    # Create a dummy callback for the legacy API
    callback = fn chunk ->
      send(self(), {:stream_chunk, chunk})
      chunk
    end

    # Convert opts to keyword list if it's a map
    opts = if is_map(opts), do: Map.to_list(opts), else: opts

    case stream(provider, messages, callback, opts) do
      :ok ->
        # Collect the stream chunks for legacy API compatibility
        stream = create_legacy_stream()
        {:ok, stream}

      error ->
        error
    end
  end

  defp create_legacy_stream do
    Stream.unfold(:collecting, fn
      :collecting ->
        receive do
          {:stream_chunk, chunk} -> {chunk, :collecting}
        after
          100 -> nil
        end

      :done ->
        nil
    end)
  end

  @doc """
  Returns the default model for a provider.

  This is a convenience function that returns sensible defaults.
  Users should prefer specifying models explicitly.
  """
  def default_model(provider) do
    case SingularityLLM.Core.Models.get_default(provider) do
      {:ok, model_id} -> model_id
      {:error, _} -> "unknown"
    end
  end

  ## Embedding Functions

  @doc """
  Generate embeddings for text input(s) using the pipeline architecture.

  This function now uses the pipeline system, providing automatic caching,
  cost tracking, circuit breakers, and other middleware benefits.

  ## Parameters

    * `provider` - The LLM provider atom (e.g., `:openai`, `:gemini`)
    * `input` - Text string or list of strings to embed
    * `opts` - Optional keyword list of options

  ## Options

    * `:model` - Override the default embedding model
    * `:dimensions` - Specify output dimensions (for supported models)
    * `:user` - User identifier for tracking (OpenAI)
    * `:encoding_format` - Encoding format (OpenAI)
    * `:cache` - Enable/disable caching (default: true)
    * `:cache_ttl` - Cache TTL in seconds

  ## Examples

      # Single text embedding
      {:ok, response} = SingularityLLM.embeddings(:openai, "Hello world")
      
      # Multiple texts
      {:ok, response} = SingularityLLM.embeddings(:openai, ["Hello", "World"])
      
      # With options
      {:ok, response} = SingularityLLM.embeddings(:openai, "Hello", 
        model: "text-embedding-3-large",
        dimensions: 512
      )

  ## Return Values

  Returns `{:ok, response}` on success where response includes:
    * `:embeddings` - List of embedding vectors
    * `:model` - The model used
    * `:usage` - Token usage information
    * `:cost` - Calculated cost in USD (if applicable)
    * `:metadata` - Provider-specific metadata

  Returns `{:error, error}` on failure.
  """
  @spec embeddings(atom(), String.t() | [String.t()], keyword()) ::
          {:ok, SingularityLLM.Types.EmbeddingResponse.t()} | {:error, term()}
  defdelegate embeddings(provider, input, opts \\ []), to: SingularityLLM.Core.Embeddings, as: :generate

  @doc """
  Lists available models for a provider using the pipeline architecture.

  This function now uses the pipeline system, providing automatic caching,
  error handling, and middleware benefits.

  ## Parameters

    * `provider` - The LLM provider atom

  ## Examples

      {:ok, models} = SingularityLLM.list_models(:openai)
      # Returns list of model structs with id, context_window, etc.
      
      {:ok, models} = SingularityLLM.list_models(:anthropic)
      # => [
      #   %{id: "claude-3-5-sonnet-20241022", context_window: 200000, ...},
      #   %{id: "claude-3-5-haiku-20241022", context_window: 200000, ...}
      # ]

  ## Return Values

  Returns `{:ok, models}` on success where models is a list of model information maps.
  Returns `{:error, error}` on failure.
  """
  @spec list_models(atom()) :: {:ok, list(Types.Model.t())} | {:error, term()}
  defdelegate list_models(provider), to: SingularityLLM.Core.Models, as: :list_for_provider

  ## Session Management Functions

  @doc "Creates a new session for conversation management. See SingularityLLM.Session.new_session/2 for details."
  defdelegate new_session(provider, opts \\ []), to: SingularityLLM.Session

  @doc "Adds a message to a session. See SingularityLLM.Session.add_message/3 for details."
  defdelegate add_message(session, role, content), to: SingularityLLM.Session

  @doc "Gets all messages from a session. See SingularityLLM.Session.get_messages/1 for details."
  defdelegate get_messages(session), to: SingularityLLM.Session

  @doc "Gets session messages with limit. See SingularityLLM.Session.get_session_messages/2 for details."
  defdelegate get_session_messages(session, limit \\ nil), to: SingularityLLM.Session

  @doc "Adds a message to a session (alias for add_message). See SingularityLLM.Session.add_session_message/3 for details."
  defdelegate add_session_message(session, role, content), to: SingularityLLM.Session

  @doc "Gets total token usage for a session. See SingularityLLM.Session.session_token_usage/1 for details."
  defdelegate session_token_usage(session), to: SingularityLLM.Session

  @doc "Clears all messages from a session. See SingularityLLM.Session.clear_session/1 for details."
  defdelegate clear_session(session), to: SingularityLLM.Session

  @doc "Saves a session to a file. See SingularityLLM.Session.save_session/2 for details."
  defdelegate save_session(session, path), to: SingularityLLM.Session

  @doc "Saves a session to JSON string. See SingularityLLM.Session.save_session/1 for details."
  defdelegate save_session(session), to: SingularityLLM.Session

  @doc "Loads a session from a file path or JSON string. See SingularityLLM.Session.load_session/1 for details."
  defdelegate load_session(path_or_json), to: SingularityLLM.Session

  @doc "Performs a chat with a session, managing context automatically. See SingularityLLM.Session.chat_session/3 for details."
  defdelegate chat_session(session, content, opts \\ []), to: SingularityLLM.Session

  @doc "Performs a chat with a session, managing context automatically. See SingularityLLM.Session.chat_with_session/3 for details."
  defdelegate chat_with_session(session, content, opts \\ []), to: SingularityLLM.Session

  ## Model Capability Functions

  @doc """
  Check if a specific model supports a capability.

  ## Examples

      SingularityLLM.model_supports?(:openai, "gpt-4-vision-preview", :vision)
      # => true
  """
  def model_supports?(provider, model_id, feature) do
    SingularityLLM.Core.Capabilities.model_supports?(provider, model_id, feature)
  end

  @doc """
  Get detailed information about a model.

  ## Examples

      {:ok, info} = SingularityLLM.get_model_info(:openai, "gpt-4")
  """
  defdelegate get_model_info(provider, model_id), to: SingularityLLM.Core.Models, as: :get_info

  @doc """
  Get model recommendations based on required features.

  ## Examples

      models = SingularityLLM.recommend_models(features: [:vision, :streaming])
  """
  def recommend_models(opts \\ []) do
    features = Keyword.get(opts, :features, [])
    SingularityLLM.Core.Models.find_by_capabilities(features)
  end

  @doc """
  Group models by a specific capability.

  ## Examples

      groups = SingularityLLM.models_by_capability(:function_calling)
  """
  def models_by_capability(capability) do
    {:ok, models} = SingularityLLM.Core.Models.find_by_capabilities([capability])
    models
  end

  @doc """
  Find models that support specific features.

  ## Examples

      models = SingularityLLM.find_models_with_features([:vision, :streaming])
  """
  defdelegate find_models_with_features(features),
    to: SingularityLLM.Core.Models,
    as: :find_by_capabilities

  ## Vision Functions

  @doc "Check if a provider/model combination supports vision. See SingularityLLM.Vision.supports_vision?/2 for details."
  defdelegate supports_vision?(provider, model), to: SingularityLLM.Vision

  @doc "Load an image from a file path or URL. See SingularityLLM.Vision.load_image/2 for details."
  defdelegate load_image(path, opts \\ []), to: SingularityLLM.Vision

  @doc "Create a vision message with text and images. See SingularityLLM.Vision.vision_message/3 for details."
  defdelegate vision_message(text, images, opts \\ []), to: SingularityLLM.Vision

  @doc "Compare models across providers."
  defdelegate compare_models(model_list), to: SingularityLLM.Core.Models, as: :compare

  @doc "Create an embedding search index from texts. See SingularityLLM.Embeddings.create_index/3 for details."
  defdelegate create_embedding_index(provider, texts, opts \\ []),
    to: SingularityLLM.Embeddings,
    as: :create_index

  ## Context Management Functions

  @doc """
  Get statistics about a conversation's context usage.

  ## Examples

      stats = SingularityLLM.context_stats(messages)
  """
  def context_stats(messages) do
    SingularityLLM.Core.Context.stats(messages)
  end

  @doc """
  Get the context window size for a specific model.

  ## Examples

      size = SingularityLLM.context_window_size(:openai, "gpt-4")
      # => 8192
  """
  def context_window_size(provider, model_id) do
    case SingularityLLM.Core.Models.get_info(provider, model_id) do
      {:ok, info} -> info.context_window
      {:error, _} -> nil
    end
  end

  @doc """
  Estimate token count for messages.

  ## Examples

      count = SingularityLLM.estimate_tokens(messages)
  """
  def estimate_tokens(messages) do
    SingularityLLM.Core.Cost.estimate_tokens(messages)
  end

  @doc """
  Count tokens for content using provider-specific token counting APIs.

  This function provides accurate token counts by using the provider's native
  token counting API, which is more precise than estimation methods.

  Currently supported providers:
  - `:gemini` - Uses Google's countTokens API

  ## Parameters

    * `provider` - The provider atom (currently only `:gemini`)
    * `model` - The model name to use for counting
    * `content` - The content to count tokens for

  ## Content Types

  For Gemini, content can be:
  - A list of messages: `[%{role: "user", content: "Hello"}]`
  - A string: `"Hello world"`
  - Content structs for multimodal input

  ## Examples

      # Count tokens for a simple message
      {:ok, response} = SingularityLLM.count_tokens(:gemini, "gemini-2.0-flash", "Hello world")
      IO.puts("Total tokens: \#{response.total_tokens}")

      # Count tokens for conversation messages
      messages = [
        %{role: "user", content: "What is machine learning?"},
        %{role: "assistant", content: "Machine learning is..."}
      ]
      {:ok, response} = SingularityLLM.count_tokens(:gemini, "gemini-2.0-flash", messages)

  ## Return Value

  Returns `{:ok, token_response}` with:
  - `total_tokens` - Total token count
  - `cached_content_token_count` - Cached tokens (if applicable)
  - `prompt_tokens_details` - Breakdown by modality
  - `cache_tokens_details` - Cache token details

  Returns `{:error, reason}` if the request fails.
  """
  @spec count_tokens(atom(), String.t(), term()) ::
          {:ok, SingularityLLM.Providers.Gemini.Tokens.CountTokensResponse.t()} | {:error, term()}
  def count_tokens(provider, model, content) do
    case Delegator.delegate(:count_tokens, provider, [model, content]) do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  ## File Management Functions

  @doc "Upload a file to the provider. See SingularityLLM.FileManager.upload_file/3 for details."
  defdelegate upload_file(provider, file_path, opts \\ []), to: SingularityLLM.FileManager

  @doc "List files uploaded to the provider. See SingularityLLM.FileManager.list_files/2 for details."
  defdelegate list_files(provider, opts \\ []), to: SingularityLLM.FileManager

  @doc "Get metadata for a specific file. See SingularityLLM.FileManager.get_file/3 for details."
  defdelegate get_file(provider, file_id, opts \\ []), to: SingularityLLM.FileManager

  @doc "Delete a file from the provider. See SingularityLLM.FileManager.delete_file/3 for details."
  defdelegate delete_file(provider, file_id, opts \\ []), to: SingularityLLM.FileManager

  @doc "Create a knowledge base (corpus) for semantic retrieval. See SingularityLLM.KnowledgeBase.create_knowledge_base/3 for details."
  defdelegate create_knowledge_base(provider, name, opts \\ []), to: SingularityLLM.KnowledgeBase

  @doc "List available knowledge bases (corpora). See SingularityLLM.KnowledgeBase.list_knowledge_bases/2 for details."
  defdelegate list_knowledge_bases(provider, opts \\ []), to: SingularityLLM.KnowledgeBase

  @doc "Get metadata for a specific knowledge base. See SingularityLLM.KnowledgeBase.get_knowledge_base/3 for details."
  defdelegate get_knowledge_base(provider, name, opts \\ []), to: SingularityLLM.KnowledgeBase

  @doc "Delete a knowledge base. See SingularityLLM.KnowledgeBase.delete_knowledge_base/3 for details."
  defdelegate delete_knowledge_base(provider, name, opts \\ []), to: SingularityLLM.KnowledgeBase

  @doc "Add a document to a knowledge base. See SingularityLLM.KnowledgeBase.add_document/4 for details."
  defdelegate add_document(provider, knowledge_base, document, opts \\ []),
    to: SingularityLLM.KnowledgeBase

  @doc "List documents in a knowledge base. See SingularityLLM.KnowledgeBase.list_documents/3 for details."
  defdelegate list_documents(provider, knowledge_base, opts \\ []), to: SingularityLLM.KnowledgeBase

  @doc "Get a specific document from a knowledge base. See SingularityLLM.KnowledgeBase.get_document/4 for details."
  defdelegate get_document(provider, knowledge_base, document_id, opts \\ []),
    to: SingularityLLM.KnowledgeBase

  @doc "Delete a document from a knowledge base. See SingularityLLM.KnowledgeBase.delete_document/4 for details."
  defdelegate delete_document(provider, knowledge_base, document_id, opts \\ []),
    to: SingularityLLM.KnowledgeBase

  @doc """
  Prepare messages for a specific provider with context management.

  ## Examples

      prepared = SingularityLLM.prepare_messages(messages, provider: :openai, model: "gpt-4")
  """
  def prepare_messages(messages, opts \\ []) do
    provider = Keyword.get(opts, :provider)
    model = Keyword.get(opts, :model)

    if provider && model do
      SingularityLLM.Core.Context.truncate_messages(messages, provider, model, opts)
    else
      messages
    end
  end

  @doc """
  Validate context for messages against provider limits.

  ## Examples

      result = SingularityLLM.validate_context(messages, provider: :openai, model: "gpt-4")
  """
  def validate_context(messages, opts \\ []) do
    provider = Keyword.get(opts, :provider)
    model = Keyword.get(opts, :model)

    if provider && model do
      # Convert string provider to atom if needed - secure conversion
      case safe_provider_to_atom(provider) do
        {:ok, provider_atom} ->
          # Use Core.Context.validate_context which returns {:ok, token_count} or {:error, reason}
          case SingularityLLM.Core.Context.validate_context(messages, provider_atom, model, opts) do
            {:ok, token_count} -> {:ok, token_count}
            {:error, reason} -> {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :missing_provider_or_model}
    end
  end

  @doc """
  Get a list of all supported providers.

  Returns a list of atoms representing the providers that SingularityLLM supports.
  Use this to discover available providers or validate provider names.

  ## Examples

      SingularityLLM.supported_providers()
      # => [:openai, :anthropic, :gemini, :groq, :mistral, :openrouter, ...]

      # Check if a provider is supported
      :openai in SingularityLLM.supported_providers()
      # => true
  """
  @spec supported_providers() :: [atom()]
  def supported_providers do
    Providers.supported_providers()
  end

  @doc """
  Check if a provider is configured and ready to use.

  This function now uses the pipeline architecture to validate configuration.

  ## Examples

      SingularityLLM.configured?(:openai)
      # => true

      SingularityLLM.configured?(:unknown_provider)  
      # => false
  """
  @spec configured?(atom()) :: boolean()
  def configured?(provider) do
    # Build request for validation
    request = Request.new(provider, [], %{})

    # Get validation pipeline for provider
    pipeline = Providers.get_pipeline(provider, :validate)

    # Run pipeline
    case Pipeline.run(request, pipeline) do
      %Request{state: :completed, result: %{configured: true}} ->
        true

      %Request{state: :completed, result: %{configured: false}} ->
        false

      %Request{state: :error} ->
        false

      _ ->
        false
    end
  end

  @doc "Performs semantic search within a knowledge base. See SingularityLLM.KnowledgeBase.semantic_search/4 for details."
  defdelegate semantic_search(provider, knowledge_base, query, opts \\ []),
    to: SingularityLLM.KnowledgeBase

  ## Context Caching Functions

  @doc "Creates cached content for efficient reuse across multiple requests. See SingularityLLM.ContextCache.create_cached_context/3 for details."
  defdelegate create_cached_context(provider, content, opts \\ []), to: SingularityLLM.ContextCache

  @doc "Retrieves cached content by name. See SingularityLLM.ContextCache.get_cached_context/3 for details."
  defdelegate get_cached_context(provider, name, opts \\ []), to: SingularityLLM.ContextCache

  @doc "Updates cached content with new information. See SingularityLLM.ContextCache.update_cached_context/4 for details."
  defdelegate update_cached_context(provider, name, updates, opts \\ []), to: SingularityLLM.ContextCache

  @doc "Deletes cached content. See SingularityLLM.ContextCache.delete_cached_context/3 for details."
  defdelegate delete_cached_context(provider, name, opts \\ []), to: SingularityLLM.ContextCache

  @doc "Lists all cached content. See SingularityLLM.ContextCache.list_cached_contexts/2 for details."
  defdelegate list_cached_contexts(provider, opts \\ []), to: SingularityLLM.ContextCache

  ## Fine-tuning Functions

  @doc "Create a fine-tuning job. See SingularityLLM.FineTuning.create_fine_tune/3 for details."
  defdelegate create_fine_tune(provider, data, opts \\ []), to: SingularityLLM.FineTuning

  @doc "List fine-tuning jobs or tuned models. See SingularityLLM.FineTuning.list_fine_tunes/2 for details."
  defdelegate list_fine_tunes(provider, opts \\ []), to: SingularityLLM.FineTuning

  @doc "Get details of a fine-tuning job or tuned model. See SingularityLLM.FineTuning.get_fine_tune/3 for details."
  defdelegate get_fine_tune(provider, id, opts \\ []), to: SingularityLLM.FineTuning

  @doc "Cancel or delete a fine-tuning job or tuned model. See SingularityLLM.FineTuning.cancel_fine_tune/3 for details."
  defdelegate cancel_fine_tune(provider, id, opts \\ []), to: SingularityLLM.FineTuning

  ## OpenAI Assistants API Functions

  @doc "Create an AI assistant. See SingularityLLM.Assistants.create_assistant/2 for details."
  defdelegate create_assistant(provider, opts \\ []), to: SingularityLLM.Assistants

  @doc "List AI assistants. See SingularityLLM.Assistants.list_assistants/2 for details."
  defdelegate list_assistants(provider, opts \\ []), to: SingularityLLM.Assistants

  @doc "Retrieve an AI assistant by ID. See SingularityLLM.Assistants.get_assistant/3 for details."
  defdelegate get_assistant(provider, assistant_id, opts \\ []), to: SingularityLLM.Assistants

  @doc "Update an AI assistant. See SingularityLLM.Assistants.update_assistant/4 for details."
  defdelegate update_assistant(provider, assistant_id, updates, opts \\ []), to: SingularityLLM.Assistants

  @doc "Delete an AI assistant. See SingularityLLM.Assistants.delete_assistant/3 for details."
  defdelegate delete_assistant(provider, assistant_id, opts \\ []), to: SingularityLLM.Assistants

  @doc "Create a conversation thread. See SingularityLLM.Assistants.create_thread/2 for details."
  defdelegate create_thread(provider, opts \\ []), to: SingularityLLM.Assistants

  @doc "Create a message in a thread. See SingularityLLM.Assistants.create_message/4 for details."
  defdelegate create_message(provider, thread_id, content, opts \\ []), to: SingularityLLM.Assistants

  @doc "Run an assistant on a thread. See SingularityLLM.Assistants.run_assistant/4 for details."
  defdelegate run_assistant(provider, thread_id, assistant_id, opts \\ []), to: SingularityLLM.Assistants

  ## Batch Processing Functions

  @doc "Create a message batch for processing multiple requests. See SingularityLLM.BatchProcessing.create_batch/3 for details."
  defdelegate create_batch(provider, messages_list, opts \\ []), to: SingularityLLM.BatchProcessing

  @doc "Get the status and details of a message batch. See SingularityLLM.BatchProcessing.get_batch/3 for details."
  defdelegate get_batch(provider, batch_id, opts \\ []), to: SingularityLLM.BatchProcessing

  @doc "Cancel a message batch that is still processing. See SingularityLLM.BatchProcessing.cancel_batch/3 for details."
  defdelegate cancel_batch(provider, batch_id, opts \\ []), to: SingularityLLM.BatchProcessing

  # Private helper function to safely convert provider strings to atoms
  # Prevents atom exhaustion attacks by validating against known providers
  @known_providers [
    :openai,
    :anthropic,
    :gemini,
    :groq,
    :mistral,
    :openrouter,
    :perplexity,
    :xai,
    :ollama,
    :lmstudio,
    :bedrock,
    :bumblebee,
    :mock
  ]

  defp safe_provider_to_atom(provider) when is_atom(provider), do: {:ok, provider}

  defp safe_provider_to_atom(provider) when is_binary(provider) do
    try do
      atom = String.to_existing_atom(provider)

      if atom in @known_providers do
        {:ok, atom}
      else
        {:error, "Unknown provider: #{provider}"}
      end
    rescue
      ArgumentError ->
        {:error, "Unknown provider: #{provider}"}
    end
  end

  defp safe_provider_to_atom(_), do: {:error, "Invalid provider type"}
end
