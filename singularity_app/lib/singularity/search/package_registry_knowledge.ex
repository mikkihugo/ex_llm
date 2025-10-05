defmodule Singularity.PackageRegistryKnowledge do
  @moduledoc """
  Package Registry Knowledge System - Structured package metadata queries (NOT RAG)

  This module provides semantic search for external packages (npm, cargo, hex, pypi)
  using structured metadata collected by Rust tool_doc_index collectors.

  ## Key Differences from RAG:

  - **Structured Data**: Queryable metadata with versions, dependencies, quality scores
  - **Curated Knowledge**: Official package information from registries
  - **Cross-Ecosystem**: Find equivalents across npm/cargo/hex/pypi
  - **Quality Signals**: Downloads, stars, recency, typescript types, etc.

  ## Usage:

      # Find packages semantically
      ToolKnowledge.search("async runtime for Rust")
      # => [%{package_name: "tokio", version: "1.35.0", ...}]

      # Get latest version
      ToolKnowledge.get_latest("tokio", ecosystem: "cargo")

      # Find cross-ecosystem equivalents
      ToolKnowledge.find_equivalents("express", from: "npm", to: "rust")
      # => [%{package_name: "actix-web", ...}, %{package_name: "axum", ...}]

      # Query with quality filters
      ToolKnowledge.search("web framework",
        ecosystem: "npm",
        min_stars: 10_000,
        has_typescript: true,
        recency_months: 6
      )
  """

  import Ecto.Query
  require Logger
  alias Singularity.Repo
  alias Singularity.Schemas.{PackageRegistryKnowledge, PackageCodeExample, PackageUsagePattern, PackageDependency}
  alias Singularity.EmbeddingGenerator

  @doc """
  Semantic search for tools using vector similarity
  """
  def search(query, opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem)
    limit = Keyword.get(opts, :limit, 10)
    min_stars = Keyword.get(opts, :min_stars, 0)
    min_downloads = Keyword.get(opts, :min_downloads, 0)
    recency_months = Keyword.get(opts, :recency_months)

    # Generate embedding for query
    {:ok, query_embedding} = EmbeddingService.generate_embedding(query)

    # Build base query
    base_query =
      from(t in PackageRegistryKnowledge,
        where: not is_nil(t.semantic_embedding),
        where: t.github_stars >= ^min_stars,
        where: t.download_count >= ^min_downloads
      )

    # Filter by ecosystem if specified
    query =
      if ecosystem do
        from t in base_query, where: t.ecosystem == ^ecosystem
      else
        base_query
      end

    # Filter by recency if specified
    query =
      if recency_months do
        cutoff_date = DateTime.utc_now() |> DateTime.add(-recency_months * 30 * 24 * 60 * 60, :second)
        from t in query, where: t.last_release_date >= ^cutoff_date
      else
        query
      end

    # Add vector similarity ordering
    from(t in query,
      select: %{
        id: t.id,
        package_name: t.package_name,
        version: t.version,
        ecosystem: t.ecosystem,
        description: t.description,
        homepage_url: t.homepage_url,
        repository_url: t.repository_url,
        license: t.license,
        github_stars: t.github_stars,
        download_count: t.download_count,
        last_release_date: t.last_release_date,
        tags: t.tags,
        keywords: t.keywords,
        similarity_score: fragment("1 - (? <-> ?)", t.semantic_embedding, ^query_embedding)
      },
      order_by: fragment("? <-> ?", t.semantic_embedding, ^query_embedding))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Get the latest version of a tool
  """
  def get_latest(package_name, opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem)

    query =
      from(t in PackageRegistryKnowledge,
        where: t.package_name == ^package_name,
        order_by: [desc: t.last_release_date],
        limit: 1

    query =
      if ecosystem do
        from t in query, where: t.ecosystem == ^ecosystem
      else
        query
      end

    Repo.one(query)
  end

  @doc """
  Get a specific version of a tool
  """
  def get_version(package_name, version, ecosystem) do
    Repo.get_by(PackageRegistryKnowledge, package_name: package_name, version: version, ecosystem: ecosystem)
  end

  @doc """
  Find cross-ecosystem equivalents
  """
  def find_equivalents(package_name, opts \\ []) do
    from_ecosystem = Keyword.get(opts, :from)
    to_ecosystem = Keyword.get(opts, :to)
    limit = Keyword.get(opts, :limit, 5)

    # Get the source tool
    source_tool =
      if from_ecosystem do
        get_latest(package_name, ecosystem: from_ecosystem)
      else
        get_latest(package_name)
      end

    if is_nil(source_tool) || is_nil(source_tool.semantic_embedding) do
      []
    else
      # Find similar tools in target ecosystem
      from(t in PackageRegistryKnowledge,
        where: t.ecosystem == ^to_ecosystem,
        where: t.package_name != ^package_name,
        where: not is_nil(t.semantic_embedding),
        select: %{
          id: t.id,
          package_name: t.package_name,
          version: t.version,
          ecosystem: t.ecosystem,
          description: t.description,
          github_stars: t.github_stars,
          similarity_score: fragment("1 - (? <-> ?)", t.semantic_embedding, ^source_tool.semantic_embedding)
        },
        order_by: fragment("? <-> ?", t.semantic_embedding, ^source_tool.semantic_embedding))
      |> limit(^limit)
      |> Repo.all()
    end
  end

  @doc """
  Get examples for a tool
  """
  def get_examples(tool_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    from(e in PackageCodeExample,
      where: e.tool_id == ^tool_id,
      order_by: [asc: e.example_order],
      )
    |> Repo.all()
  end

  @doc """
  Search for code examples across all tools
  """
  def search_examples(query, opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem)
    language = Keyword.get(opts, :language)
    limit = Keyword.get(opts, :limit, 10)

    # Generate embedding for query
    {:ok, query_embedding} = EmbeddingService.generate_embedding(query)

    # Build base query
    base_query =
      from(e in PackageCodeExample,
        join: t in PackageRegistryKnowledge, on: e.tool_id == t.id,
        where: not is_nil(e.code_embedding)

    # Filter by ecosystem if specified
    query =
      if ecosystem do
        from [e, t] in base_query, where: t.ecosystem == ^ecosystem
      else
        base_query
      end

    # Filter by language if specified
    query =
      if language do
        from [e, t] in query, where: e.language == ^language
      else
        query
      end

    # Add vector similarity ordering
    from([e, t] in query,
      select: %{
        example_id: e.id,
        package_name: t.package_name,
        version: t.version,
        ecosystem: t.ecosystem,
        title: e.title,
        code: e.code,
        language: e.language,
        explanation: e.explanation,
        similarity_score: fragment("1 - (? <-> ?)", e.code_embedding, ^query_embedding)
      },
      order_by: fragment("? <-> ?", e.code_embedding, ^query_embedding),
      )
    |> Repo.all()
  end

  @doc """
  Get best practices and patterns for a tool
  """
  def get_patterns(tool_id, opts \\ []) do
    pattern_type = Keyword.get(opts, :pattern_type)

    query =
      from(p in PackageUsagePattern,
        where: p.tool_id == ^tool_id

    query =
      if pattern_type do
        from p in query, where: p.pattern_type == ^pattern_type
      else
        query
      end

    from p in query, order_by: [asc: :id]
    |> Repo.all()
  end

  @doc """
  Search for patterns across all tools
  """
  def search_patterns(query, opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem)
    pattern_type = Keyword.get(opts, :pattern_type)
    limit = Keyword.get(opts, :limit, 10)

    # Generate embedding for query
    {:ok, query_embedding} = EmbeddingService.generate_embedding(query)

    # Build base query
    base_query =
      from(p in PackageUsagePattern,
        join: t in PackageRegistryKnowledge, on: p.tool_id == t.id,
        where: not is_nil(p.pattern_embedding)

    # Filter by ecosystem if specified
    query =
      if ecosystem do
        from [p, t] in base_query, where: t.ecosystem == ^ecosystem
      else
        base_query
      end

    # Filter by pattern type if specified
    query =
      if pattern_type do
        from [p, t] in query, where: p.pattern_type == ^pattern_type
      else
        query
      end

    # Add vector similarity ordering
    from([p, t] in query,
      select: %{
        pattern_id: p.id,
        package_name: t.package_name,
        version: t.version,
        ecosystem: t.ecosystem,
        pattern_type: p.pattern_type,
        title: p.title,
        description: p.description,
        code_example: p.code_example,
        similarity_score: fragment("1 - (? <-> ?)", p.pattern_embedding, ^query_embedding)
      },
      order_by: fragment("? <-> ?", p.pattern_embedding, ^query_embedding),
      )
    |> Repo.all()
  end

  @doc """
  Get dependencies for a tool
  """
  def get_dependencies(tool_id, opts \\ []) do
    dependency_type = Keyword.get(opts, :dependency_type)

    query =
      from(d in PackageDependency,
        where: d.tool_id == ^tool_id

    query =
      if dependency_type do
        from d in query, where: d.dependency_type == ^dependency_type
      else
        query
      end

    from d in query, order_by: [asc: :dependency_name]
    |> Repo.all()
  end

  @doc """
  Get popular tools by ecosystem
  """
  def get_popular(ecosystem, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    sort_by = Keyword.get(opts, :sort_by, :github_stars) # or :download_count

    from(t in PackageRegistryKnowledge,
      where: t.ecosystem == ^ecosystem,
      order_by: [desc: field(t, ^sort_by)],
      )
    |> Repo.all()
  end

  @doc """
  Get recently updated tools
  """
  def get_recent(ecosystem, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    days = Keyword.get(opts, :days, 30)

    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(t in PackageRegistryKnowledge,
      where: t.ecosystem == ^ecosystem,
      where: t.last_release_date >= ^cutoff_date,
      order_by: [desc: t.last_release_date],
      )
    |> Repo.all()
  end

  @doc """
  Upsert a tool (used by Rust collectors)
  """
  def upsert_tool(attrs) do
    % PackageRegistryKnowledge{}
    |> PackageRegistryKnowledge.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:package_name, :version, :ecosystem]
    )
  end

  @doc """
  Upsert a tool example
  """
  def upsert_example(attrs) do
    %PackageCodeExample{}
    |> PackageCodeExample.changeset(attrs)
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:id])
  end

  @doc """
  Upsert a tool pattern
  """
  def upsert_pattern(attrs) do
    %PackageUsagePattern{}
    |> PackageUsagePattern.changeset(attrs)
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:id])
  end

  @doc """
  Upsert a tool dependency
  """
  def upsert_dependency(attrs) do
    %PackageDependency{}
    |> PackageDependency.changeset(attrs)
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:id])
  end
end
