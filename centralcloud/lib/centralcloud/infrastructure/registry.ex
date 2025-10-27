defmodule CentralCloud.Infrastructure.Registry do
  @moduledoc """
  Infrastructure Registry Service - Query and manage infrastructure system definitions.

  Provides the interface for infrastructure system discovery, creation, and learning
  as part of Phase 8 (Infrastructure Learning in CentralCloud).

  ## Usage

      # Get all high-confidence systems
      {:ok, systems} = Registry.get_all_systems(min_confidence: 0.8)

      # Get systems by category
      {:ok, brokers} = Registry.get_systems_by_category("message_brokers")

      # Create or update a system
      {:ok, system} = Registry.upsert_system(%{
        name: "Kafka",
        category: "message_brokers",
        detection_patterns: ["kafka.yml", "kafkajs"],
        confidence: 0.85
      })

      # Record detection result and update confidence
      {:ok, system} = Registry.record_detection("Istio", "service_mesh", true)
  """

  import Ecto.Query
  alias CentralCloud.Repo
  alias CentralCloud.Schemas.InfrastructureSystem

  require Logger

  @doc """
  Get all infrastructure systems with optional filtering.

  ## Options

    - min_confidence: Minimum confidence threshold (default: 0.5)
    - limit: Maximum number of results (default: no limit)
    - order_by: How to sort results (default: confidence desc, then inserted_at desc)

  ## Examples

      {:ok, systems} = Registry.get_all_systems()
      {:ok, systems} = Registry.get_all_systems(min_confidence: 0.8)
  """
  @spec get_all_systems(keyword()) :: {:ok, [InfrastructureSystem.t()]} | {:error, term()}
  def get_all_systems(opts \\ []) do
    min_confidence = Keyword.get(opts, :min_confidence, 0.5)
    limit = Keyword.get(opts, :limit)

    query =
      InfrastructureSystem
      |> where([s], s.confidence >= ^min_confidence)
      |> order_by([s], [desc: s.confidence, desc: s.inserted_at])

    query =
      if limit do
        limit(query, ^limit)
      else
        query
      end

    try do
      systems = Repo.all(query)
      {:ok, group_by_category(systems)}
    rescue
      e ->
        Logger.error("Failed to fetch all infrastructure systems: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Get infrastructure systems by category.

  ## Options

    - min_confidence: Minimum confidence threshold (default: 0.5)
    - limit: Maximum number of results (default: no limit)

  ## Examples

      {:ok, brokers} = Registry.get_systems_by_category("message_brokers")
      {:ok, meshes} = Registry.get_systems_by_category("service_mesh", min_confidence: 0.8)
  """
  @spec get_systems_by_category(String.t(), keyword()) ::
          {:ok, [InfrastructureSystem.t()]} | {:error, term()}
  def get_systems_by_category(category, opts \\ []) do
    min_confidence = Keyword.get(opts, :min_confidence, 0.5)
    limit = Keyword.get(opts, :limit)

    query =
      InfrastructureSystem
      |> where([s], s.category == ^category)
      |> where([s], s.confidence >= ^min_confidence)
      |> order_by([s], [desc: s.confidence, desc: s.inserted_at])

    query =
      if limit do
        limit(query, ^limit)
      else
        query
      end

    try do
      systems = Repo.all(query)
      {:ok, systems}
    rescue
      e ->
        Logger.error("Failed to fetch systems by category #{category}: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Get a single infrastructure system by name and category.

  ## Examples

      {:ok, system} = Registry.get_system("Kafka", "message_brokers")
      {:error, :not_found} = Registry.get_system("Unknown", "database")
  """
  @spec get_system(String.t(), String.t()) ::
          {:ok, InfrastructureSystem.t()} | {:error, :not_found}
  def get_system(name, category) do
    case Repo.get_by(InfrastructureSystem, name: name, category: category) do
      nil -> {:error, :not_found}
      system -> {:ok, system}
    end
  end

  @doc """
  Create or update an infrastructure system.

  ## Examples

      {:ok, system} = Registry.upsert_system(%{
        name: "Kafka",
        category: "message_brokers",
        description: "Apache Kafka distributed message broker",
        detection_patterns: ["kafka.yml", "kafkajs"],
        fields: %{"topics" => "array"},
        source: "llm",
        confidence: 0.85
      })
  """
  @spec upsert_system(map()) ::
          {:ok, InfrastructureSystem.t()} | {:error, Ecto.Changeset.t()}
  def upsert_system(attrs) do
    InfrastructureSystem.upsert(
      attrs["name"] || attrs[:name],
      attrs["category"] || attrs[:category],
      attrs
    )
  end

  @doc """
  Record a detection result for an infrastructure system.

  Updates the confidence score based on detection success/failure:
  - Success: +0.05 confidence
  - Failure: -0.10 confidence

  Bounds confidence to [0.0, 1.0] and updates last_validated_at.

  ## Examples

      {:ok, system} = Registry.record_detection("Kafka", "message_brokers", true)
      {:ok, system} = Registry.record_detection("Istio", "service_mesh", false)
  """
  @spec record_detection(String.t(), String.t(), boolean()) ::
          {:ok, InfrastructureSystem.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :not_found}
  def record_detection(name, category, detected?) do
    InfrastructureSystem.record_detection_result(name, category, detected?)
  end

  @doc """
  Batch record detection results from a detection run.

  Updates confidence for multiple systems based on detection results.

  ## Examples

      results = [
        {"Kafka", "message_brokers", true},
        {"RabbitMQ", "message_brokers", false},
        {"Istio", "service_mesh", true}
      ]
      Registry.batch_record_detections(results)
  """
  @spec batch_record_detections([{String.t(), String.t(), boolean()}]) :: :ok
  def batch_record_detections(results) do
    Enum.each(results, fn {name, category, detected?} ->
      Task.start(fn ->
        record_detection(name, category, detected?)
      end)
    end)

    :ok
  end

  @doc """
  Get a formatted registry suitable for responding to infrastructure.registry NATS queries.

  Returns all systems grouped by category, filtered by min_confidence.

  ## Examples

      {:ok, registry} = Registry.get_formatted_registry(min_confidence: 0.8)
      # Returns:
      # %{
      #   "message_brokers" => [%{"name" => "Kafka", ...}],
      #   "service_mesh" => [%{"name" => "Istio", ...}],
      #   ...
      # }
  """
  @spec get_formatted_registry(keyword()) :: {:ok, map()} | {:error, term()}
  def get_formatted_registry(opts \\ []) do
    with {:ok, grouped} <- get_all_systems(opts) do
      # grouped is already a map from group_by_category
      formatted =
        grouped
        |> Enum.map(fn {category, systems} ->
          {
            category,
            systems
            |> Enum.map(&system_to_map/1)
          }
        end)
        |> Enum.into(%{})

      {:ok, formatted}
    end
  end

  @doc """
  Seed initial infrastructure systems from a list.

  Useful for populating default systems when CentralCloud is first initialized.

  ## Examples

      systems = [
        %{
          name: "Kafka",
          category: "message_brokers",
          detection_patterns: ["kafka.yml"],
          confidence: 0.95,
          source: "manual"
        },
        ...
      ]
      Registry.seed_initial_systems(systems)
  """
  @spec seed_initial_systems([map()]) :: {:ok, integer()} | {:error, term()}
  def seed_initial_systems(systems) do
    Logger.info("Seeding #{length(systems)} initial infrastructure systems...")

    try do
      count =
        Enum.reduce(systems, 0, fn system, acc ->
          case upsert_system(system) do
            {:ok, _} -> acc + 1
            {:error, reason} -> Logger.warning("Failed to seed system: #{inspect(reason)}"); acc
          end
        end)

      Logger.info("Seeded #{count}/#{length(systems)} infrastructure systems")
      {:ok, count}
    rescue
      e ->
        Logger.error("Error seeding infrastructure systems: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Get statistics about infrastructure systems.

  Returns counts by category and overall confidence metrics.

  ## Examples

      {:ok, stats} = Registry.get_statistics()
      # Returns:
      # %{
      #   "total" => 14,
      #   "by_category" => %{"message_brokers" => 4, ...},
      #   "avg_confidence" => 0.82,
      #   "high_confidence_count" => 12
      # }
  """
  @spec get_statistics() :: {:ok, map()} | {:error, term()}
  def get_statistics do
    try do
      total = Repo.aggregate(InfrastructureSystem, :count, :id)

      by_category =
        InfrastructureSystem
        |> group_by([s], s.category)
        |> select([s], {s.category, count(s.id)})
        |> Repo.all()
        |> Enum.into(%{})

      avg_confidence =
        InfrastructureSystem
        |> select([s], avg(s.confidence))
        |> Repo.one()
        |> (fn v -> v || 0.0 end).()

      high_confidence_count =
        InfrastructureSystem
        |> where([s], s.confidence >= 0.8)
        |> Repo.aggregate(:count, :id)

      stats = %{
        "total" => total,
        "by_category" => by_category,
        "avg_confidence" => Float.round(avg_confidence, 2),
        "high_confidence_count" => high_confidence_count
      }

      {:ok, stats}
    rescue
      e ->
        Logger.error("Failed to get infrastructure statistics: #{inspect(e)}")
        {:error, e}
    end
  end

  # Private

  defp group_by_category(systems) do
    systems
    |> Enum.reduce(%{}, fn system, acc ->
      category = system.category
      Map.update(acc, category, [system], &[system | &1])
    end)
  end

  defp system_to_map(system) do
    %{
      "name" => system.name,
      "category" => system.category,
      "description" => system.description,
      "detection_patterns" => system.detection_patterns,
      "fields" => system.fields,
      "source" => system.source,
      "confidence" => system.confidence,
      "last_validated_at" => system.last_validated_at,
      "learned_at" => system.learned_at
    }
  end
end
