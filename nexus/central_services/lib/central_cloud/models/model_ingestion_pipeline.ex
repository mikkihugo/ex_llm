defmodule CentralCloud.Models.ModelIngestionPipeline do
  @moduledoc """
  Model Ingestion Pipeline for CentralCloud.
  
  Orchestrates the ingestion of models from multiple sources:
  1. Live models from models.dev API (real-time pricing)
  2. Static YAML models (custom definitions)
  3. Custom models (manually added)
  
  Handles massive context windows (up to 10M+ tokens) and complexity scoring.
  """

  alias CentralCloud.Models.{ModelCache, ComplexityScorer, MLComplexityTrainer}
  alias CentralCloud.Repo

  @doc """
  Run the complete model ingestion pipeline.
  """
  def run_full_ingestion do
    IO.puts("🚀 Starting Model Ingestion Pipeline...")
    
    with {:ok, _} <- ingest_models_dev(),
         {:ok, _} <- ingest_yaml_models(),
         {:ok, _} <- ingest_custom_models(),
         {:ok, _} <- update_complexity_scores(),
         {:ok, _} <- train_ml_models() do
      IO.puts("✅ Model ingestion pipeline completed successfully!")
      {:ok, :completed}
    else
      {:error, reason} ->
        IO.puts("❌ Model ingestion pipeline failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Ingest models from models.dev API.
  """
  def ingest_models_dev do
    IO.puts("📡 Ingesting models from models.dev...")
    
    case fetch_models_dev() do
      {:ok, models} ->
        IO.puts("   Found #{length(models)} models from models.dev")
        
        results = Enum.map(models, &ingest_single_model_dev/1)
        
        success_count = Enum.count(results, &match?({:ok, _}, &1))
        IO.puts("   Successfully ingested #{success_count}/#{length(models)} models")
        
        {:ok, results}
      {:error, reason} ->
        IO.puts("   ❌ Failed to fetch from models.dev: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Ingest models from YAML static definitions.
  """
  def ingest_yaml_models do
    IO.puts("📄 Ingesting YAML static models...")
    
    yaml_files = find_yaml_model_files()
    IO.puts("   Found #{length(yaml_files)} YAML model files")
    
    results = Enum.map(yaml_files, &ingest_single_yaml_model/1)
    
    success_count = Enum.count(results, &match?({:ok, _}, &1))
    IO.puts("   Successfully ingested #{success_count}/#{length(yaml_files)} YAML models")
    
    {:ok, results}
  end

  @doc """
  Ingest custom models.
  """
  def ingest_custom_models do
    IO.puts("🔧 Ingesting custom models...")
    
    custom_models = get_custom_models()
    IO.puts("   Found #{length(custom_models)} custom models")
    
    results = Enum.map(custom_models, &ingest_single_custom_model/1)
    
    success_count = Enum.count(results, &match?({:ok, _}, &1))
    IO.puts("   Successfully ingested #{success_count}/#{length(custom_models)} custom models")
    
    {:ok, results}
  end

  @doc """
  Update complexity scores for all models.
  """
  def update_complexity_scores do
    IO.puts("🧠 Updating complexity scores...")
    
    models = Repo.all(ModelCache)
    IO.puts("   Updating #{length(models)} models")
    
    results = Enum.map(models, &update_model_complexity/1)
    
    success_count = Enum.count(results, &match?({:ok, _}, &1))
    IO.puts("   Successfully updated #{success_count}/#{length(models)} complexity scores")
    
    {:ok, results}
  end

  @doc """
  Train ML models for complexity prediction.
  """
  def train_ml_models do
    IO.puts("🤖 Training ML complexity models...")
    
    case MLComplexityTrainer.train_complexity_model() do
      {:ok, _model} ->
        IO.puts("   ✅ ML model training completed")
        {:ok, :trained}
      {:error, :insufficient_data} ->
        IO.puts("   ⚠️  Insufficient data for ML training (need 100+ samples)")
        {:ok, :insufficient_data}
      {:error, reason} ->
        IO.puts("   ❌ ML training failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp fetch_models_dev do
    # Fetch from models.dev API
    case :httpc.request(:get, {'https://models.dev/api.json', []}, [], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        case Jason.decode(body) do
          {:ok, models} -> {:ok, models}
          {:error, reason} -> {:error, {:json_decode, reason}}
        end
      {:ok, {{_, status, _}, _, _}} ->
        {:error, {:http_status, status}}
      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp ingest_single_model_dev(model_data) do
    # Enhance model data with complexity scoring
    enhanced_data = enhance_model_data(model_data)
    
    # Create or update model
    case Repo.get_by(ModelCache, model_id: enhanced_data["id"]) do
      nil ->
        create_model_from_data(enhanced_data, "models_dev")
      existing_model ->
        update_model_from_data(existing_model, enhanced_data)
    end
  end

  defp ingest_single_yaml_model(yaml_file) do
    case load_yaml_file(yaml_file) do
      {:ok, model_data} ->
        enhanced_data = enhance_model_data(model_data)
        create_model_from_data(enhanced_data, "yaml_static")
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ingest_single_custom_model(custom_model) do
    enhanced_data = enhance_model_data(custom_model)
    create_model_from_data(enhanced_data, "custom")
  end

  defp enhance_model_data(model_data) do
    # Add complexity scoring and other enhancements
    model_data
    |> Map.put("complexity_score", calculate_initial_complexity(model_data))
    |> Map.put("context_length_category", categorize_context_length(model_data))
    |> Map.put("ingested_at", DateTime.utc_now())
  end

  defp calculate_initial_complexity(model_data) do
    # Create a mock model struct for complexity calculation
    mock_model = %ModelCache{
      model_id: model_data["id"],
      provider_id: model_data["provider"],
      specifications: model_data["specifications"],
      pricing: model_data["pricing"],
      capabilities: model_data["capabilities"]
    }
    
    case ComplexityScorer.calculate_complexity_score(mock_model) do
      %{score: score} -> score
      _ -> 0.5  # Default complexity
    end
  end

  defp categorize_context_length(model_data) do
    context_length = get_in(model_data, ["specifications", "context_length"]) || 0
    
    cond do
      context_length < 4_000 -> "ultra_small"
      context_length < 16_000 -> "small"
      context_length < 64_000 -> "medium"
      context_length < 200_000 -> "large"
      context_length < 1_000_000 -> "very_large"
      context_length < 10_000_000 -> "massive"
      true -> "ultra_massive"
    end
  end

  defp create_model_from_data(model_data, source) do
    attrs = %{
      model_id: model_data["id"],
      provider_id: model_data["provider"],
      name: model_data["name"] || model_data["id"],
      description: model_data["description"],
      pricing: model_data["pricing"],
      capabilities: model_data["capabilities"],
      specifications: model_data["specifications"],
      source: source,
      status: "active",
      metadata: %{
        "original_data" => model_data,
        "complexity_score" => model_data["complexity_score"],
        "context_length_category" => model_data["context_length_category"],
        "ingested_at" => model_data["ingested_at"]
      },
      cached_at: DateTime.utc_now(),
      last_verified_at: DateTime.utc_now()
    }

    %ModelCache{}
    |> ModelCache.changeset(attrs)
    |> Repo.insert()
  end

  defp update_model_from_data(existing_model, model_data) do
    attrs = %{
      name: model_data["name"] || model_data["id"],
      description: model_data["description"],
      pricing: model_data["pricing"],
      capabilities: model_data["capabilities"],
      specifications: model_data["specifications"],
      metadata: Map.merge(existing_model.metadata || %{}, %{
        "original_data" => model_data,
        "complexity_score" => model_data["complexity_score"],
        "context_length_category" => model_data["context_length_category"],
        "ingested_at" => model_data["ingested_at"]
      }),
      last_verified_at: DateTime.utc_now()
    }

    existing_model
    |> ModelCache.changeset(attrs)
    |> Repo.update()
  end

  defp update_model_complexity(model) do
    case ComplexityScorer.calculate_complexity_score(model) do
      %{score: score, confidence: confidence} ->
        attrs = %{
          metadata: Map.merge(model.metadata || %{}, %{
            "complexity_score" => score,
            "complexity_confidence" => confidence,
            "complexity_updated_at" => DateTime.utc_now()
          })
        }

        model
        |> ModelCache.changeset(attrs)
        |> Repo.update()
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_yaml_model_files do
    # Find YAML model files in the project
    # This would scan for *.yml files in models/ directory
    []
  end

  defp load_yaml_file(yaml_file) do
    # Load and parse YAML file
    # This would use YAML parsing library
    {:ok, %{}}
  end

  defp get_custom_models do
    # Get custom models from configuration or database
    []
  end
end
