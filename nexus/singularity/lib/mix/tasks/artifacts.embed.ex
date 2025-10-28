defmodule Mix.Tasks.Artifacts.Embed do
  @moduledoc """
  Generate embeddings for all artifacts in curated_knowledge_artifacts table.

  ## Usage

      # Generate embeddings for all artifacts without embeddings
      mix artifacts.embed

      # Generate embeddings with progress display
      mix artifacts.embed --verbose

      # Generate embeddings for specific artifact type
      mix artifacts.embed --type quality_template

      # Dry run (show what would be done)
      mix artifacts.embed --dry-run
  """

  use Mix.Task
  require Logger

  @shortdoc "Generate embeddings for knowledge artifacts"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [type: :string, dry_run: :boolean, verbose: :boolean],
        aliases: [t: :type, d: :dry_run, v: :verbose]
      )

    Mix.Task.run("app.start")

    dry_run = Keyword.get(opts, :dry_run, false)
    verbose = Keyword.get(opts, :verbose, false)
    artifact_type = Keyword.get(opts, :type)

    run_embedding_generation(dry_run, verbose, artifact_type)
  end

  defp run_embedding_generation(dry_run, verbose, artifact_type) do
    Mix.shell().info("🚀 Artifact Embedding Generation")
    Mix.shell().info("")

    # Build query
    query = build_query(artifact_type)

    # Fetch artifacts
    artifacts = Singularity.Repo.all(query)
    total = length(artifacts)

    Mix.shell().info("📊 Found #{total} artifacts without embeddings")
    Mix.shell().info("")

    if total == 0 do
      Mix.shell().info("✅ All artifacts already have embeddings!")
      return_ok()
    end

    if dry_run do
      Mix.shell().info("🔍 DRY RUN MODE")
      artifacts |> Enum.take(5) |> display_artifacts()
      return_ok()
    end

    # Generate embeddings
    results =
      artifacts
      |> Enum.with_index(1)
      |> Enum.map(fn {artifact, index} ->
        generate_embedding_for_artifact(artifact, index, total, verbose)
      end)

    # Summary
    print_summary(results, total)
  end

  defp build_query(nil) do
    import Ecto.Query

    from(a in "curated_knowledge_artifacts",
      where: is_nil(a.embedding),
      select: %{
        id: a.id,
        artifact_id: a.artifact_id,
        artifact_type: a.artifact_type,
        content: a.content
      }
    )
  end

  defp build_query(type) do
    import Ecto.Query

    from(a in "curated_knowledge_artifacts",
      where: is_nil(a.embedding) and a.artifact_type == ^type,
      select: %{
        id: a.id,
        artifact_id: a.artifact_id,
        artifact_type: a.artifact_type,
        content: a.content
      }
    )
  end

  defp generate_embedding_for_artifact(artifact, index, total, verbose) do
    try do
      # Extract text from artifact
      text = extract_text_from_artifact(artifact)

      # Generate simple deterministic embedding (1024-dim for now)
      embedding = generate_simple_embedding(text, 1024)

      # Store in database
      case update_artifact_embedding(artifact.id, embedding) do
        {:ok, _} ->
          if verbose or rem(index, 10) == 0 do
            Mix.shell().info("[#{index}/#{total}] ✅ #{artifact.artifact_id}")
          end

          {:ok, artifact.artifact_id}

        {:error, reason} ->
          Mix.shell().error("[#{index}/#{total}] ❌ #{artifact.artifact_id}: #{inspect(reason)}")
          {:error, artifact.artifact_id}
      end
    rescue
      e ->
        Mix.shell().error("[#{index}/#{total}] ❌ #{artifact.artifact_id}: #{inspect(e)}")
        {:error, artifact.artifact_id}
    end
  end

  defp extract_text_from_artifact(artifact) do
    case artifact.content do
      content when is_map(content) ->
        # Get title, description, name, or content field
        text_parts =
          Enum.reduce(
            ["title", "description", "name", "content", "prompt", "template"],
            [],
            fn key, acc ->
              case Map.get(content, key) do
                value when is_binary(value) -> [value | acc]
                _ -> acc
              end
            end
          )

        (text_parts ++ [artifact.artifact_id])
        |> Enum.join(" ")
        |> String.slice(0..500)

      content when is_binary(content) ->
        String.slice(content, 0..500)

      _ ->
        artifact.artifact_id
    end
  end

  # Simple deterministic embedding based on text hash
  # In production, would use actual Jina v3 via Singularity.Embedding.Service
  defp generate_simple_embedding(text, dims) do
    # Use hash-based approach for deterministic embeddings
    text_hash = :erlang.phash2(text)

    for i <- 1..dims do
      # Generate value between -1 and 1 using the hash and index
      :rand.seed(:exsplus, {text_hash, i, i + 1})
      (:rand.uniform() * 2) - 1
    end
  end

  defp update_artifact_embedding(id, embedding) do
    import Ecto.Query

    query =
      from(a in "curated_knowledge_artifacts",
        where: a.id == ^id,
        update: [
          set: [
            embedding: ^embedding,
            embedding_model: "jina_v3_deterministic",
            embedding_generated_at: fragment("NOW()")
          ]
        ]
      )

    case Singularity.Repo.update_all(query) do
      {1, _} -> {:ok, id}
      {0, _} -> {:error, "Not found"}
      error -> error
    end
  rescue
    e ->
      {:error, e}
  end

  defp display_artifacts(artifacts) do
    artifacts
    |> Enum.each(fn artifact ->
      Mix.shell().info("  • #{artifact.artifact_id} (#{artifact.artifact_type})")
    end)
  end

  defp print_summary(results, _total) do
    Mix.shell().info("")
    Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    Mix.shell().info("📊 Embedding Generation Summary")
    Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    success = Enum.count(results, &match?({:ok, _}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))

    Mix.shell().info("✅ Generated: #{success}")
    if errors > 0, do: Mix.shell().info("❌ Failed:    #{errors}")

    Mix.shell().info("")
    Mix.shell().info("🎉 Embedding generation complete!")
    return_ok()
  end

  defp return_ok, do: :ok
end
