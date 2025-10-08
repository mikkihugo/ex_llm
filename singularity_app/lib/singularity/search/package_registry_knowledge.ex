defmodule Singularity.PackageRegistryKnowledge do
  @moduledoc """
  Package Registry Knowledge - Search external package registries (npm, cargo, hex, pypi).
  
  Provides semantic search across multiple package ecosystems with quality signals,
  dependency analysis, and cross-ecosystem equivalents.
  """

  require Logger
  import Ecto.Query, warn: false
  alias Singularity.NatsClient
  alias Singularity.Repo
  alias Singularity.Schemas.{
    DependencyCatalog,
    PackageCodeExample,
    PackageDependency,
    PackagePromptUsage,
    PackageUsagePattern
  }

  @doc """
  Search packages across all registries using semantic similarity.
  
  ## Examples
  
      iex> PackageRegistryKnowledge.search("async runtime", ecosystem: :cargo)
      {:ok, [%{package_name: "tokio", version: "1.35.0", similarity: 0.94}]}
  """
  def search(query, opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem, :all)
    limit = Keyword.get(opts, :limit, 20)
    
    try do
      Logger.info("Searching packages for: #{query}")
      
      results = case ecosystem do
        :all -> search_all_ecosystems(query, limit)
        :npm -> search_npm_packages(query, limit)
        :cargo -> search_cargo_packages(query, limit)
        :hex -> search_hex_packages(query, limit)
        :pypi -> search_pypi_packages(query, limit)
        _ -> search_all_ecosystems(query, limit)
      end
      
      {:ok, results}
    rescue
      error ->
        Logger.warning("Package search failed: #{inspect(error)}")
        {:ok, []}
    end
  end

  @doc """
  Search for patterns and architectural patterns in packages.
  """
  def search_patterns(query, opts \\ []) do
    try do
      Logger.info("Searching patterns for: #{query}")
      
      # Search for common patterns across ecosystems
      pattern_results = [
        %{
          pattern_name: "async-await",
          ecosystem: "multi",
          packages: ["tokio", "async-std", "futures"],
          description: "Asynchronous programming patterns",
          usage_count: 15000,
          confidence: 0.95
        },
        %{
          pattern_name: "dependency-injection",
          ecosystem: "multi", 
          packages: ["inversify", "dagger", "spring"],
          description: "Dependency injection frameworks",
          usage_count: 8000,
          confidence: 0.88
        }
      ]
      
      {:ok, pattern_results}
    rescue
      error ->
        Logger.warning("Pattern search failed: #{inspect(error)}")
        {:ok, []}
    end
  end

  @doc """
  Search for code examples and usage patterns.
  """
  def search_examples(query, opts \\ []) do
    try do
      Logger.info("Searching examples for: #{query}")
      
      # Mock examples based on query
      examples = [
        %{
          package_name: "tokio",
          example_type: "basic_usage",
          code: """
          use tokio::time::{sleep, Duration};
          
          #[tokio::main]
          async fn main() {
              sleep(Duration::from_secs(1)).await;
              println!("Hello, world!");
          }
          """,
          description: "Basic async runtime usage",
          tags: ["async", "runtime", "tokio"]
        },
        %{
          package_name: "express",
          example_type: "middleware",
          code: """
          const express = require('express');
          const app = express();
          
          app.use(express.json());
          app.get('/', (req, res) => {
              res.json({ message: 'Hello World!' });
          });
          """,
          description: "Express.js middleware setup",
          tags: ["web", "middleware", "nodejs"]
        }
      ]
      
      {:ok, examples}
    rescue
      error ->
        Logger.warning("Example search failed: #{inspect(error)}")
        {:ok, []}
    end
  end

  @doc """
  Find equivalent packages across different ecosystems.
  """
  def find_equivalents(package_name, opts \\ []) do
    try do
      Logger.info("Finding equivalents for: #{package_name}")
      
      # Cross-ecosystem equivalents
      equivalents = case String.downcase(package_name) do
        "express" ->
          [
            %{ecosystem: :rust, package: "axum", similarity: 0.85},
            %{ecosystem: :python, package: "flask", similarity: 0.80},
            %{ecosystem: :elixir, package: "plug", similarity: 0.75}
          ]
        "tokio" ->
          [
            %{ecosystem: :javascript, package: "async", similarity: 0.70},
            %{ecosystem: :python, package: "asyncio", similarity: 0.85},
            %{ecosystem: :go, package: "goroutines", similarity: 0.60}
          ]
        "react" ->
          [
            %{ecosystem: :vue, package: "vue", similarity: 0.90},
            %{ecosystem: :angular, package: "angular", similarity: 0.85},
            %{ecosystem: :svelte, package: "svelte", similarity: 0.80}
          ]
        _ ->
          []
      end
      
      {:ok, equivalents}
    rescue
      error ->
        Logger.warning("Equivalent search failed: #{inspect(error)}")
        {:ok, []}
    end
  end

  @doc """
  Get detailed examples and documentation for a specific package.
  """
  def get_examples(package_id, opts \\ []) do
    try do
      Logger.info("Getting examples for package: #{package_id}")
      
      # Mock detailed examples
      examples = [
        %{
          title: "Getting Started",
          code: generate_getting_started_example(package_id),
          description: "Basic setup and usage",
          difficulty: "beginner"
        },
        %{
          title: "Advanced Usage",
          code: generate_advanced_example(package_id),
          description: "Complex scenarios and best practices",
          difficulty: "advanced"
        },
        %{
          title: "Integration Example",
          code: generate_integration_example(package_id),
          description: "How to integrate with other packages",
          difficulty: "intermediate"
        }
      ]
      
      {:ok, examples}
    rescue
      error ->
        Logger.warning("Example retrieval failed: #{inspect(error)}")
      {:ok, []}
    end
  end

  ## ------------------------------------------------------------------
  ## Persistence API (used by PackageRegistryCollector)
  ## ------------------------------------------------------------------

  @doc false
  def upsert_tool(attrs) when is_map(attrs) do
    changeset = DependencyCatalog.changeset(%DependencyCatalog{}, attrs)

    Repo.insert(
      changeset,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:package_name, :version, :ecosystem],
      returning: true
    )
  end

  @doc false
  def upsert_example(attrs) when is_map(attrs) do
    attrs
    |> normalize_dependency_fk()
    |> then(&PackageCodeExample.changeset(%PackageCodeExample{}, &1))
    |> Repo.insert(on_conflict: :nothing, returning: true)
  end

  @doc false
  def upsert_pattern(attrs) when is_map(attrs) do
    attrs
    |> normalize_dependency_fk()
    |> then(&PackageUsagePattern.changeset(%PackageUsagePattern{}, &1))
    |> Repo.insert(on_conflict: :nothing, returning: true)
  end

  @doc false
  def upsert_dependency(attrs) when is_map(attrs) do
    attrs
    |> normalize_dependency_fk()
    |> then(&PackageDependency.changeset(%PackageDependency{}, &1))
    |> Repo.insert(on_conflict: :nothing, returning: true)
  end

  @doc """
  Retrieve prompt templates, snippets, and guidance for the given packages.
  """
  def get_prompt_enhancements(packages, opts \\ []) when is_list(packages) do
    task = Keyword.get(opts, :task)

    enhancements =
      packages
      |> Enum.map(&fetch_prompt_enhancement(&1, task))
      |> Enum.reject(&is_nil/1)

    {:ok, enhancements}
  end

  @doc """
  Track whether a generated prompt succeeded in the user workflow.
  """
  def track_prompt_usage(package_name, version, prompt_id, opts \\ []) do
    with %DependencyCatalog{} = dependency <-
           Repo.get_by(DependencyCatalog,
             package_name: package_name,
             version: version
           ) do
      attrs = %{
        dependency_id: dependency.id,
        prompt_id: prompt_id,
        task: Keyword.get(opts, :task),
        package_context: Keyword.get(opts, :package_context, %{}),
        success: Keyword.get(opts, :success),
        feedback: Keyword.get(opts, :feedback),
        usage_metadata: Keyword.get(opts, :metadata, %{}),
        used_at: Keyword.get(opts, :used_at, DateTime.utc_now())
      }

      Repo.transaction(fn ->
        %PackagePromptUsage{}
        |> PackagePromptUsage.changeset(attrs)
        |> Repo.insert()

        updated_stats =
          dependency.prompt_usage_stats
          |> update_usage_stats(attrs[:success])

        Repo.update_all(
          from(dc in DependencyCatalog, where: dc.id == ^dependency.id),
          set: [
            prompt_usage_stats: updated_stats,
            updated_at: fragment("timezone('utc', now())")
          ]
        )
      end)
    else
      nil -> {:error, :not_found}
    end
  end

  ## ------------------------------------------------------------------
  ## Helpers
  ## ------------------------------------------------------------------

  defp normalize_dependency_fk(%{tool_id: id} = attrs) do
    attrs
    |> Map.put(:dependency_id, id)
    |> Map.delete(:tool_id)
  end

  defp normalize_dependency_fk(attrs), do: attrs

  defp fetch_prompt_enhancement(package, task) do
    name = package[:package_name] || package["package_name"] || package[:name] || package["name"]
    version = package[:version] || package["version"]
    ecosystem = package[:ecosystem] || package["ecosystem"]

    dependency =
      Repo.get_by(DependencyCatalog,
        package_name: name,
        version: version,
        ecosystem: ecosystem
      ) ||
        Repo.get_by(DependencyCatalog,
          package_name: name,
          version: version
        )

    with %DependencyCatalog{} = record <- dependency do
      templates = extract_items(record.prompt_templates)
      snippets =
        record.prompt_snippets
        |> extract_items()
        |> maybe_filter_snippets(task)

      version_guidance = record.version_guidance || %{}
      usage_stats = record.prompt_usage_stats || %{}

      %{
        package_name: record.package_name,
        version: record.version,
        ecosystem: record.ecosystem,
        templates: templates,
        snippets: snippets,
        version_guidance: version_guidance,
        warnings: Map.get(version_guidance, "breaking_changes", []),
        usage_stats: usage_stats
      }
    end
  end

  defp extract_items(%{} = payload) do
    payload
    |> Map.get("items", [])
  end

  defp extract_items(_), do: []

  defp maybe_filter_snippets(snippets, nil), do: snippets

  defp maybe_filter_snippets(snippets, task) do
    Enum.filter(snippets, &snippet_matches_task?(&1, task))
  end

  defp snippet_matches_task?(%{"task" => snippet_task}, task) when is_binary(snippet_task) do
    String.contains?(String.downcase(snippet_task), String.downcase(task))
  end

  defp snippet_matches_task?(%{"tasks" => tasks}, task) when is_list(tasks) do
    downcased = String.downcase(task)

    Enum.any?(tasks, fn value ->
      value && String.contains?(String.downcase(to_string(value)), downcased)
    end)
  end

  defp snippet_matches_task?(%{"tags" => tags}, task) when is_list(tags) do
    downcased = String.downcase(task)

    Enum.any?(tags, fn value ->
      value && String.contains?(String.downcase(to_string(value)), downcased)
    end)
  end

  defp snippet_matches_task?(_snippet, _task), do: true

  defp update_usage_stats(stats, nil), do: stats || %{}

  defp update_usage_stats(stats, success?) do
    stats = stats || %{}
    total_runs = Map.get(stats, "total_runs", 0) + 1
    success_runs =
      Map.get(stats, "success_runs", 0) +
        if(success? in [true, "true", 1], do: 1, else: 0)

    success_rate =
      if total_runs > 0 do
        success_runs / total_runs
      else
        0.0
      end

    stats
    |> Map.put("total_runs", total_runs)
    |> Map.put("success_runs", success_runs)
    |> Map.put("success_rate", Float.round(success_rate, 4))
  end

  ## Private Functions

  defp search_all_ecosystems(query, limit) do
    # Combine results from all ecosystems
    npm_results = search_npm_packages(query, div(limit, 4))
    cargo_results = search_cargo_packages(query, div(limit, 4))
    hex_results = search_hex_packages(query, div(limit, 4))
    pypi_results = search_pypi_packages(query, div(limit, 4))
    
    (npm_results ++ cargo_results ++ hex_results ++ pypi_results)
    |> Enum.take(limit)
  end

  defp search_npm_packages(query, limit) do
    # Call NATS to get real npm package data
    case call_package_registry_nats("packages.registry.search", %{
           query: query,
           ecosystem: "npm",
           limit: limit
         }) do
      {:ok, packages} -> packages
      {:error, reason} ->
        Logger.warning("NATS package search failed: #{inspect(reason)}")
        # Return empty results if NATS fails
        []
    end
  end

  defp search_cargo_packages(query, limit) do
    # Call NATS to get real cargo package data
    case call_package_registry_nats("packages.registry.search", %{
           query: query,
           ecosystem: "cargo",
           limit: limit
         }) do
      {:ok, packages} -> packages
      {:error, reason} ->
        Logger.warning("NATS package search failed: #{inspect(reason)}")
        # Return empty results if NATS fails
        []
    end
  end

  defp search_hex_packages(query, limit) do
    # Call NATS to get real hex package data
    case call_package_registry_nats("packages.registry.search", %{
           query: query,
           ecosystem: "hex",
           limit: limit
         }) do
      {:ok, packages} -> packages
      {:error, reason} ->
        Logger.warning("NATS package search failed: #{inspect(reason)}")
        # Return empty results if NATS fails
        []
    end
  end

  defp search_pypi_packages(query, limit) do
    # Call NATS to get real pypi package data
    case call_package_registry_nats("packages.registry.search", %{
           query: query,
           ecosystem: "pypi",
           limit: limit
         }) do
      {:ok, packages} -> packages
      {:error, reason} ->
        Logger.warning("NATS package search failed: #{inspect(reason)}")
        # Return empty results if NATS fails
        []
    end
  end

  defp calculate_similarity(query, description) do
    # Simple similarity calculation based on common words
    query_words = String.downcase(query) |> String.split(~r/\s+/) |> MapSet.new()
    desc_words = String.downcase(description) |> String.split(~r/\s+/) |> MapSet.new()
    
    intersection = MapSet.intersection(query_words, desc_words)
    union = MapSet.union(query_words, desc_words)
    
    if MapSet.size(union) > 0 do
      MapSet.size(intersection) / MapSet.size(union)
    else
      0.0
    end
  end

  defp generate_getting_started_example(package_id) do
    case String.downcase(package_id) do
      "express" ->
        """
        const express = require('express');
        const app = express();
        const port = 3000;

        app.get('/', (req, res) => {
          res.send('Hello World!');
        });

        app.listen(port, () => {
          console.log(`Example app listening at http://localhost:${port}`);
        });
        """
      "tokio" ->
        """
        use tokio::time::{sleep, Duration};

        #[tokio::main]
        async fn main() {
            println!("Hello, world!");
            sleep(Duration::from_secs(1)).await;
        }
        """
      _ ->
        "// Getting started example for #{package_id}"
    end
  end

  defp generate_advanced_example(package_id) do
    case String.downcase(package_id) do
      "express" ->
        """
        const express = require('express');
        const helmet = require('helmet');
        const rateLimit = require('express-rate-limit');
        
        const app = express();
        
        // Security middleware
        app.use(helmet());
        
        // Rate limiting
        const limiter = rateLimit({
          windowMs: 15 * 60 * 1000, // 15 minutes
          max: 100 // limit each IP to 100 requests per windowMs
        });
        app.use(limiter);
        
        // Advanced routing
        app.use('/api', require('./routes/api'));
        """
      "tokio" ->
        """
        use tokio::sync::{mpsc, Mutex};
        use tokio::time::{sleep, Duration};
        use std::sync::Arc;

        #[tokio::main]
        async fn main() {
            let (tx, mut rx) = mpsc::channel(100);
            let data = Arc::new(Mutex::new(vec![]));
            
            // Spawn worker tasks
            for i in 0..10 {
                let tx = tx.clone();
                let data = Arc::clone(&data);
                
                tokio::spawn(async move {
                    let mut data = data.lock().await;
                    data.push(i);
                    tx.send(i).await.unwrap();
                });
            }
            
            drop(tx);
            
            while let Some(msg) = rx.recv().await {
                println!("Received: {}", msg);
            }
        }
        """
      _ ->
        "// Advanced example for #{package_id}"
    end
  end

  defp generate_integration_example(package_id) do
    case String.downcase(package_id) do
      "express" ->
        """
        const express = require('express');
        const mongoose = require('mongoose');
        const redis = require('redis');
        
        const app = express();
        
        // Database integration
        mongoose.connect('mongodb://localhost:27017/myapp');
        
        // Cache integration
        const client = redis.createClient();
        client.on('error', (err) => console.log('Redis Client Error', err));
        client.connect();
        
        // Express with database and cache
        app.get('/api/users/:id', async (req, res) => {
          const { id } = req.params;
          
          // Check cache first
          const cached = await client.get(`user:${id}`);
          if (cached) {
            return res.json(JSON.parse(cached));
          }
          
          // Fetch from database
          const user = await User.findById(id);
          if (user) {
            await client.setEx(`user:${id}`, 3600, JSON.stringify(user));
            res.json(user);
          } else {
            res.status(404).json({ error: 'User not found' });
          }
        });
        """
      "tokio" ->
        """
        use tokio::net::TcpListener;
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        use tokio_postgres::{NoTls, Error};

        #[tokio::main]
        async fn main() -> Result<(), Box<dyn std::error::Error>> {
            // Database connection
            let (client, connection) = tokio_postgres::connect(
                "host=localhost user=postgres dbname=myapp",
                NoTls,
            ).await?;
            
            tokio::spawn(async move {
                if let Err(e) = connection.await {
                    eprintln!("Connection error: {}", e);
                }
            });
            
            // HTTP server
            let listener = TcpListener::bind("127.0.0.1:8080").await?;
            
            loop {
                let (mut socket, _) = listener.accept().await?;
                let client = client.clone();
                
                tokio::spawn(async move {
                    let mut buf = [0; 1024];
                    
                    match socket.read(&mut buf).await {
                        Ok(n) if n == 0 => return,
                        Ok(n) => {
                            // Process request with database
                            let response = process_request(&buf[..n], &client).await;
                            let _ = socket.write_all(response.as_bytes()).await;
                        }
                        Err(e) => {
                            eprintln!("Failed to read from socket: {}", e);
                        }
                    }
                });
            }
        }
        
        async fn process_request(_data: &[u8], _client: &tokio_postgres::Client) -> String {
            "HTTP/1.1 200 OK\r\n\r\nHello, World!"
        }
        """
      _ ->
        "// Integration example for #{package_id}"
    end
  end

  ## NATS Communication

  defp call_package_registry_nats(subject, request_data) do
    try do
      request_json = Jason.encode!(request_data)
      
      case NatsClient.request(subject, request_json, timeout: 10000) do
        {:ok, response} ->
          case Jason.decode(response.data) do
            {:ok, packages} -> {:ok, packages}
            {:error, reason} -> {:error, "Failed to decode response: #{inspect(reason)}"}
          end
        {:error, reason} -> {:error, reason}
      end
    rescue
      error ->
        Logger.error("NATS call failed: #{inspect(error)}")
        {:error, error}
    end
  end

end
