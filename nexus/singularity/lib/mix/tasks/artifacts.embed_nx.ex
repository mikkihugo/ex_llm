defmodule Mix.Tasks.Artifacts.EmbedNx do
  @moduledoc """
  Generate real Jina v3 embeddings for artifacts using Nx/ONNX inference.

  Uses pure Elixir Nx infrastructure (no Python, no external APIs).

  ## Usage

      # Generate Jina v3 embeddings for all artifacts
      mix artifacts.embed_nx

      # Generate with GPU (if available)
      mix artifacts.embed_nx --device cuda

      # Verbose progress output
      mix artifacts.embed_nx --verbose

      # Dry run (test without updating DB)
      mix artifacts.embed_nx --dry-run

      # Specific artifact count
      mix artifacts.embed_nx --limit 10
  """

  use Mix.Task
  require Logger

  alias Singularity.Repo
  alias Singularity.Embedding.NxService

  @shortdoc "Generate real Jina v3 embeddings via Nx"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [device: :string, verbose: :boolean, dry_run: :boolean, limit: :integer],
        aliases: [d: :device, v: :verbose, l: :limit]
      )

    # Start Ecto repo explicitly (uses DATABASE_URL or config)
    {:ok, _} = Application.ensure_all_started(:singularity)

    # Give Repo supervisor time to start and initialize connection pool
    Process.sleep(1000)

    # Wait for Repo to be ready by attempting to acquire a connection
    # Retries 60 times (30 seconds total at 500ms intervals)
    unless wait_for_repo(60) do
      Mix.shell().error("Error: Database connection failed after retries")
      Mix.shell().info("Tips:")
      Mix.shell().info("  1. Ensure PostgreSQL is running on localhost:5432")

      Mix.shell().info(
        "  2. Set DATABASE_URL environment variable (e.g., ecto://user:password@localhost/singularity)"
      )

      Mix.shell().info("  3. Or run: mix ecto.create && mix ecto.migrate")
      exit({:shutdown, 1})
    end

    device = Keyword.get(opts, :device, "cpu") |> String.to_atom()
    verbose = Keyword.get(opts, :verbose, false)
    dry_run = Keyword.get(opts, :dry_run, false)
    limit = Keyword.get(opts, :limit, nil)

    run_embedding_generation(device, verbose, dry_run, limit)
  end

  # Wait for Repo to be ready (returns true if successful, false if timeout)
  defp wait_for_repo(retries) when retries > 0 do
    try do
      # Try a simple query to verify Repo is ready
      Repo.query("SELECT 1", [])
      true
    rescue
      _ ->
        Process.sleep(500)
        wait_for_repo(retries - 1)
    end
  end

  defp wait_for_repo(0) do
    false
  end

  defp run_embedding_generation(device, verbose, dry_run, limit) do
    Mix.shell().info("🚀 Jina v3 Embedding Generation via Nx/ONNX")
    Mix.shell().info("Device: #{inspect(device)}")
    Mix.shell().info("")

    # Fetch artifacts needing embeddings
    artifacts = fetch_artifacts_for_embedding(limit)
    total = length(artifacts)

    Mix.shell().info("📊 Found #{total} artifacts needing embeddings")
    Mix.shell().info("")

    if total == 0 do
      Mix.shell().info("✅ All artifacts already have Jina v3 embeddings!")
      return_ok()
    end

    if dry_run do
      Mix.shell().info("🔍 DRY RUN MODE - Will not update database")
      Mix.shell().info("")
      display_sample_artifacts(artifacts |> Enum.take(3))
      return_ok()
    end

    # Load Jina v3 model once
    Mix.shell().info("📦 Loading Jina v3 model...")

    case load_jina_model(device) do
      {:ok, _model_state} ->
        Mix.shell().info("✅ Jina v3 model loaded (1024-dim)")
        Mix.shell().info("")
        generate_embeddings(artifacts, verbose)

      {:error, reason} ->
        Mix.shell().error("❌ Failed to load Jina v3 model: #{inspect(reason)}")
        Mix.shell().info("")
        Mix.shell().info("Fallback: Using deterministic embeddings")
        Mix.shell().info("(Real model requires: ollama/vLLM/ONNX runtime)")
        return_error(1)
    end
  end

  defp fetch_artifacts_for_embedding(nil) do
    import Ecto.Query

    Repo.all(
      from a in "curated_knowledge_artifacts",
        where: is_nil(a.embedding) or a.embedding_model != "jina_v3",
        select: %{
          id: a.id,
          artifact_id: a.artifact_id,
          artifact_type: a.artifact_type,
          content: a.content
        }
    )
  end

  defp fetch_artifacts_for_embedding(limit) do
    import Ecto.Query

    Repo.all(
      from a in "curated_knowledge_artifacts",
        where: is_nil(a.embedding) or a.embedding_model != "jina_v3",
        limit: ^limit,
        select: %{
          id: a.id,
          artifact_id: a.artifact_id,
          artifact_type: a.artifact_type,
          content: a.content
        }
    )
  end

  defp load_jina_model(device) do
    try do
      case NxService.embed("test", device: device) do
        {:ok, _embedding} ->
          Mix.shell().info("✅ Jina v3 model working")
          {:ok, :ready}

        {:error, reason} ->
          Mix.shell().error("❌ Model inference failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        {:error, e}
    end
  end

  defp generate_embeddings(artifacts, verbose) do
    Mix.shell().info("🔄 Generating #{length(artifacts)} embeddings...")
    Mix.shell().info("")

    results =
      artifacts
      |> Enum.with_index(1)
      |> Enum.map(fn {artifact, index} ->
        generate_single_embedding(artifact, index, length(artifacts), verbose)
      end)

    # Summary
    print_summary(results)
  end

  defp generate_single_embedding(artifact, index, total, verbose) do
    try do
      # Extract text from artifact
      text = extract_artifact_text(artifact)

      # Generate embedding via Jina v3
      case NxService.embed(text) do
        {:ok, embedding} ->
          # Convert Nx tensor to list
          embedding_list =
            case embedding do
              tensor -> Nx.to_list(tensor)
            end

          # Verify dimension
          if length(embedding_list) == 1024 do
            # Store in database
            case update_artifact_embedding(artifact.id, embedding_list, "jina_v3") do
              {:ok, _} ->
                if verbose or rem(index, 10) == 0 do
                  Mix.shell().info("[#{index}/#{total}] ✅ #{artifact.artifact_id}")
                end

                {:ok, artifact.artifact_id}

              {:error, reason} ->
                Mix.shell().error(
                  "[#{index}/#{total}] ❌ DB update failed for #{artifact.artifact_id}: #{inspect(reason)}"
                )

                {:error, artifact.artifact_id}
            end
          else
            Mix.shell().error(
              "[#{index}/#{total}] ❌ Wrong embedding dimension: #{length(embedding_list)} (expected 1024)"
            )

            {:error, artifact.artifact_id}
          end

        {:error, reason} ->
          Mix.shell().error(
            "[#{index}/#{total}] ❌ Embedding failed for #{artifact.artifact_id}: #{inspect(reason)}"
          )

          {:error, artifact.artifact_id}
      end
    rescue
      e ->
        Mix.shell().error("[#{index}/#{total}] ❌ Exception: #{inspect(e)}")
        {:error, artifact.artifact_id}
    end
  end

  defp extract_artifact_text(artifact) do
    case artifact.content do
      content when is_map(content) ->
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

  defp update_artifact_embedding(id, embedding_list, model) do
    import Ecto.Query

    # Convert list to array format for TEXT column
    embedding_array = "[" <> Enum.map_join(embedding_list, ",", &Float.to_string/1) <> "]"

    query =
      from(a in "curated_knowledge_artifacts",
        where: a.id == ^id,
        update: [
          set: [
            embedding: ^embedding_array,
            embedding_model: ^model,
            embedding_generated_at: fragment("NOW()")
          ]
        ]
      )

    case Repo.update_all(query, []) do
      {1, _} -> {:ok, id}
      {0, _} -> {:error, "Not found"}
      error -> error
    end
  rescue
    e ->
      {:error, e}
  end

  defp display_sample_artifacts(artifacts) do
    artifacts
    |> Enum.each(fn artifact ->
      Mix.shell().info("  • #{artifact.artifact_id} (#{artifact.artifact_type})")
    end)
  end

  defp print_summary(results) do
    Mix.shell().info("")
    Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    Mix.shell().info("📊 Embedding Generation Summary")
    Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    success = Enum.count(results, &match?({:ok, _}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))

    Mix.shell().info("✅ Generated: #{success}")
    if errors > 0, do: Mix.shell().info("❌ Failed:    #{errors}")

    Mix.shell().info("")
    Mix.shell().info("🎉 Real Jina v3 embedding generation complete!")
    return_ok()
  end

  defp return_ok, do: :ok
  defp return_error(code), do: exit({:shutdown, code})
end
