defmodule CentralCloud.PromptManagement do
  @moduledoc """
  Prompt Management Service for CentralCloud - Complete Implementation
  
  Stores and manages prompts in CentralCloud's PostgreSQL database with pgvector
  for semantic search.
  
  ## Features
  
  - Store prompts in PostgreSQL (`templates` table with category='prompt')
  - Generate embeddings using CentralCloud's EmbeddingEngine (2560-dim)
  - Semantic search using pgvector
  - Template versioning and metadata
  
  ## Architecture
  
  ```
  Prompt → EmbeddingEngine (via pgflow) → pgvector → PostgreSQL
  ```
  
  ## Examples
  
  ```elixir
  # Store a prompt with automatic embedding generation
  {:ok, prompt} = PromptManagement.store_prompt(%{
    template_name: "framework-discovery",
    template_content: "Analyze this code for framework patterns...",
    template_type: "discovery",
    language: "elixir"
  })
  
  # Search prompts semantically
  {:ok, prompts} = PromptManagement.search_by_similarity(
    "detect web framework patterns",
    limit: 5
  )
  
  # Get best matching prompt for a task
  {:ok, prompt} = PromptManagement.get_best_match("analyze react components")
  ```
  """

  require Logger
  import Ecto.Query

  alias CentralCloud.{Repo, Engines.EmbeddingEngine}
  alias CentralCloud.Schemas.Template

  @doc """
  Store a prompt template with automatic embedding generation.
  
  If embedding is not provided, it will be generated using EmbeddingEngine.
  """
  def store_prompt(attrs, opts \\ []) do
    # Normalize to template format
    template_data = %{
      "id" => attrs[:template_name] || attrs["template_name"],
      "category" => "prompt",
      "metadata" => %{
        "name" => attrs[:template_name] || attrs["template_name"],
        "description" => attrs[:template_content] || attrs["template_content"] || "",
        "language" => attrs[:language] || attrs["language"] || "general"
      },
      "content" => %{
        "type" => "prompt",
        "system" => attrs[:template_content] || attrs["template_content"] || "",
        "user" => ""
      },
      "version" => attrs[:version] || attrs["version"] || "1.0.0"
    }
    
    # Use TemplateService to store
    CentralCloud.TemplateService.store_template(template_data)
  end

  @doc """
  Search prompts by semantic similarity using pgvector.
  
  ## Options
  
  - `:limit` - Maximum number of results (default: 10)
  - `:threshold` - Minimum similarity score (default: 0.7)
  - `:language` - Filter by language (optional)
  - `:template_type` - Filter by template type (optional)
  """
  def search_by_similarity(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    threshold = Keyword.get(opts, :threshold, 0.7)
    language = Keyword.get(opts, :language)
    template_type = Keyword.get(opts, :template_type)

    # Generate query embedding
    case EmbeddingEngine.embed_text(query) do
      {:ok, query_embedding} ->
        # Build query with pgvector similarity search on templates table
        query_builder =
          from(t in Template,
            where: t.category == "prompt" and not is_nil(t.embedding),
            # Calculate cosine similarity (pgvector operator)
            select: %{
              template: t,
              similarity: fragment("1 - (? <=> ?)", t.embedding, ^query_embedding)
            },
            order_by: [
              asc: fragment("? <=> ?", t.embedding, ^query_embedding)
            ],
            limit: ^limit
          )

        # Apply filters
        query_builder =
          query_builder
          |> maybe_apply_filter(language, fn q, lang ->
            where(q, [t], fragment("?->>'language'", t.metadata) == ^lang)
          end)
          |> maybe_apply_filter(template_type, fn q, type ->
            where(q, [t], fragment("?->>'type'", t.metadata) == ^type)
          end)

        results = Repo.all(query_builder)

        # Filter by threshold (similarity = 1 - distance)
        filtered =
          results
          |> Enum.filter(fn %{similarity: similarity} -> similarity >= threshold end)
          |> Enum.sort_by(fn %{similarity: similarity} -> similarity end, :desc)
          |> Enum.take(limit)

        {:ok, Enum.map(filtered, fn %{template: template, similarity: similarity} -> 
          {template_to_map(template), similarity} 
        end)}

      {:error, reason} ->
        Logger.error("Failed to generate query embedding: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp template_to_map(template) do
    %{
      id: template.id,
      category: template.category,
      metadata: template.metadata,
      content: template.content,
      version: template.version
    }
  end

  @doc """
  Get the best matching prompt for a task description.
  
  Returns the most similar prompt template with its similarity score.
  """
  def get_best_match(query, opts \\ []) do
    case search_by_similarity(query, Keyword.put(opts, :limit, 1)) do
      {:ok, [{prompt, similarity}]} when similarity >= 0.7 ->
        {:ok, prompt, similarity}

      {:ok, []} ->
        {:error, :no_match_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get prompt by ID.
  """
  def get_prompt(prompt_id) do
    case CentralCloud.TemplateService.get_template(prompt_id, category: "prompt") do
      {:ok, template} -> {:ok, template}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_prompts(opts \\ []) do
    opts = Keyword.put(opts, :category, "prompt")
    CentralCloud.TemplateService.list_templates(opts)
  end

  def update_embedding(prompt_id) do
    # Use TemplateService to update embedding
    case CentralCloud.TemplateService.get_template(prompt_id) do
      {:ok, template} ->
        # Regenerate embedding
        search_text = build_search_text_from_template(template)
        
        case generate_embedding(search_text) do
          {:ok, embedding} ->
            # Update via TemplateService
            template_data = Map.put(template, "embedding", embedding)
            CentralCloud.TemplateService.store_template(template_data)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_search_text_from_template(template) do
    metadata = template[:metadata] || template["metadata"] || %{}
    content = template[:content] || template["content"] || %{}
    
    [
      Map.get(metadata, "name") || Map.get(metadata, :name),
      Map.get(metadata, "description") || Map.get(metadata, :description),
      Map.get(content, "system") || Map.get(content, :system) || ""
    ]
    |> Enum.join(" ")
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp generate_embedding(text) when is_binary(text) and text != "" do
    # Use CentralCloud's EmbeddingEngine (delegates to Singularity via pgflow)
    # Returns 2560-dim vector (Qodo 1536 + Jina v3 1024)
    case EmbeddingEngine.embed_text(text) do
      {:ok, embedding} when is_list(embedding) -> {:ok, embedding}
      {:ok, embedding} -> {:ok, embedding}
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_embedding(_), do: {:error, :empty_text}
  defp maybe_apply_filter(query, nil, _fun), do: query
  defp maybe_apply_filter(query, value, fun), do: fun.(query, value)
end
