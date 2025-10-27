defmodule CentralCloud.Schemas.InfrastructureSystem do
  @moduledoc """
  InfrastructureSystem Schema - Infrastructure system definitions (Phase 8).

  Stores infrastructure systems with LLM-researched detection patterns.
  Enables dynamic infrastructure support without code changes.

  ## Schema Fields

  - **name** (string) - System identifier (Kubernetes, Istio, etc.)
  - **category** (string) - Infrastructure category (service_mesh, api_gateway, etc.)
  - **description** (text) - Human-readable description
  - **detection_patterns** (jsonb array) - File names/env vars for detection
  - **fields** (jsonb map) - Configuration field names/types
  - **source** (string) - "llm", "manual", or "research"
  - **confidence** (float) - 0.0-1.0 confidence score
  - **last_validated_at** (utc_datetime) - When detection was last verified
  - **learned_at** (utc_datetime) - When LLM first learned about this system
  - **timestamps** - Audit trail

  ## Examples

      iex> CentralCloud.Schemas.InfrastructureSystem.changeset(%CentralCloud.Schemas.InfrastructureSystem{}, %{
      ...>   name: "Kubernetes",
      ...>   category: "container_orchestration",
      ...>   description: "Kubernetes container orchestration",
      ...>   detection_patterns: ["kubernetes", "k8s", ".kube"],
      ...>   fields: %{"namespaces" => "array"},
      ...>   source: "llm",
      ...>   confidence: 0.95
      ...> })
      {:ok, %CentralCloud.Schemas.InfrastructureSystem{...}}
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CentralCloud.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "infrastructure_systems" do
    field :name, :string
    field :category, :string
    field :description, :string
    field :detection_patterns, {:array, :string}, default: []
    field :fields, :map, default: %{}
    field :source, :string, default: "manual"
    field :confidence, :float, default: 0.5
    field :last_validated_at, :utc_datetime_usec
    field :learned_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @type t() :: %__MODULE__{
    id: binary() | nil,
    name: String.t() | nil,
    category: String.t() | nil,
    description: String.t() | nil,
    detection_patterns: [String.t()],
    fields: map(),
    source: String.t(),
    confidence: float(),
    last_validated_at: DateTime.t() | nil,
    learned_at: DateTime.t() | nil,
    inserted_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }

  @doc """
  Build a changeset for creating or updating an infrastructure system.

  Validates required fields and confidence bounds.

  ## Examples

      iex> changeset(%InfrastructureSystem{}, %{"name" => "Kafka", "category" => "message_broker"})
      %Ecto.Changeset{...}
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(system, attrs) do
    system
    |> cast(attrs, [
      :name,
      :category,
      :description,
      :detection_patterns,
      :fields,
      :source,
      :confidence,
      :last_validated_at,
      :learned_at
    ])
    |> validate_required([:name, :category])
    |> validate_confidence()
    |> validate_source()
    |> unique_constraint([:name, :category], name: :infrastructure_systems_name_category_index)
  end

  @doc """
  Get or create an infrastructure system by name and category.

  Returns the existing system if found, or creates a new one with the provided attributes.

  ## Examples

      iex> get_or_create("Kafka", "message_broker", %{
      ...>   detection_patterns: ["kafka.yml"],
      ...>   confidence: 0.85
      ...> })
      {:ok, %InfrastructureSystem{...}}
  """
  @spec get_or_create(String.t(), String.t(), map()) ::
          {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def get_or_create(name, category, attrs \\ %{}) do
    case Repo.get_by(__MODULE__, name: name, category: category) do
      nil ->
        %__MODULE__{}
        |> changeset(Map.merge(%{"name" => name, "category" => category}, attrs))
        |> Repo.insert()

      existing ->
        {:ok, existing}
    end
  end

  @doc """
  Update or create an infrastructure system by name and category.

  Updates the existing system if found, or creates a new one with the provided attributes.
  Updates last_validated_at to current time.

  ## Examples

      iex> upsert("Istio", "service_mesh", %{
      ...>   detection_patterns: ["istio.io", "istiod"],
      ...>   confidence: 0.92
      ...> })
      {:ok, %InfrastructureSystem{...}}
  """
  @spec upsert(String.t(), String.t(), map()) ::
          {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def upsert(name, category, attrs \\ %{}) do
    attrs_with_timestamp = Map.put(attrs, :last_validated_at, DateTime.utc_now())

    case Repo.get_by(__MODULE__, name: name, category: category) do
      nil ->
        %__MODULE__{}
        |> changeset(
          Map.merge(%{"name" => name, "category" => category}, attrs_with_timestamp)
        )
        |> Repo.insert()

      existing ->
        existing
        |> changeset(attrs_with_timestamp)
        |> Repo.update()
    end
  end

  @doc """
  Record a detection result and update confidence.

  Increases confidence if detection was successful, decreases if missed.

  ## Examples

      iex> record_detection_result("Kafka", "message_broker", true)
      {:ok, %InfrastructureSystem{...}}
  """
  @spec record_detection_result(String.t(), String.t(), boolean()) ::
          {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()} | {:error, :not_found}
  def record_detection_result(name, category, detected?) do
    case Repo.get_by(__MODULE__, name: name, category: category) do
      nil ->
        {:error, :not_found}

      system ->
        current_confidence = system.confidence
        adjustment = if detected?, do: 0.05, else: -0.10

        new_confidence =
          (current_confidence + adjustment)
          |> max(0.0)
          |> min(1.0)

        system
        |> changeset(%{confidence: new_confidence, last_validated_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  # Private

  defp validate_confidence(changeset) do
    validate_number(changeset, :confidence,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
  end

  defp validate_source(changeset) do
    validate_inclusion(changeset, :source, ["llm", "manual", "research"])
  end
end
