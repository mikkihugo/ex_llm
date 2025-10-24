defmodule Singularity.Schemas.UsageEvent do
  @moduledoc """
  Usage events for tracking suggestion acceptance and learning patterns.

  This schema tracks how users interact with suggestions from the meta-registry
  to improve the learning system over time.

  ## Purpose:

  - Track which suggestions are accepted vs rejected
  - Learn from user behavior to improve future suggestions
  - Build confidence scores for different suggestion types
  - Identify patterns that work well for specific codebases

  ## Usage:

      # Record a usage event
      {:ok, event} = UsageEvent.create(%{
        codebase_id: "my-app",
        category: "naming",
        suggestion: "UserController",
        accepted: true,
        context: %{language: "php", framework: "laravel"}
      })
      
      # Query acceptance rates
      acceptance_rate = UsageEvent.acceptance_rate("naming", "my-app")
      
  ## Schema Fields:

  - `codebase_id` - Which codebase this event relates to
  - `category` - Type of suggestion (naming, architecture, pattern, etc.)
  - `suggestion` - The actual suggestion that was made
  - `accepted` - Whether the user accepted the suggestion
  - `context` - Additional context (language, framework, etc.)
  - `confidence` - How confident the system was in this suggestion
  - `inserted_at` - When the event occurred
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "usage_events" do
    field :codebase_id, :string
    field :category, :string
    field :suggestion, :string
    field :accepted, :boolean
    field :context, :map
    field :confidence, :float

    timestamps()
  end

  @doc false
  def changeset(usage_event, attrs) do
    usage_event
    |> cast(attrs, [:codebase_id, :category, :suggestion, :accepted, :context, :confidence])
    |> validate_required([:codebase_id, :category, :suggestion, :accepted])
    |> validate_inclusion(:category, [
      "naming",
      "architecture",
      "pattern",
      "refactoring",
      "structure"
    ])
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end

  @doc """
  Create a new usage event.

  ## Examples

      {:ok, event} = UsageEvent.create(%{
        codebase_id: "my-app",
        category: "naming",
        suggestion: "UserController",
        accepted: true,
        context: %{language: "php", framework: "laravel"},
        confidence: 0.85
      })
  """
  def create(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset -> {:ok, changeset}
      changeset -> {:error, changeset}
    end
  end

  @doc """
  Calculate acceptance rate for a category and codebase.

  ## Examples

      acceptance_rate = UsageEvent.acceptance_rate("naming", "my-app")
      # => 0.75 (75% acceptance rate)
  """
  def acceptance_rate(category, codebase_id) do
    import Ecto.Query

    query = from u in __MODULE__,
      where: u.category == ^category and u.codebase_id == ^codebase_id,
      select: %{
        total: count(u.id),
        accepted: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", u.accepted))
      }

    case Singularity.Repo.one(query) do
      %{total: 0} -> 0.0
      %{total: total, accepted: accepted} when not is_nil(accepted) ->
        accepted / total
      _ -> 0.0
    end
  end

  @doc """
  Get usage statistics for a codebase.

  ## Examples

      stats = UsageEvent.stats("my-app")
      # => %{total_events: 100, acceptance_rate: 0.75, categories: %{...}}
  """
  def stats(codebase_id) do
    import Ecto.Query

    # Get overall stats
    overall_query = from u in __MODULE__,
      where: u.codebase_id == ^codebase_id,
      select: %{
        total_events: count(u.id),
        accepted: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", u.accepted))
      }

    overall = Singularity.Repo.one(overall_query) || %{total_events: 0, accepted: 0}

    # Get per-category stats
    category_query = from u in __MODULE__,
      where: u.codebase_id == ^codebase_id,
      group_by: u.category,
      select: {u.category, %{
        total: count(u.id),
        accepted: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", u.accepted))
      }}

    categories =
      category_query
      |> Singularity.Repo.all()
      |> Enum.into(%{}, fn {cat, stats} -> {String.to_atom(cat), stats} end)

    acceptance_rate =
      case overall do
        %{total_events: 0} -> 0.0
        %{total_events: total, accepted: accepted} when not is_nil(accepted) ->
          accepted / total
        _ -> 0.0
      end

    %{
      total_events: overall.total_events || 0,
      acceptance_rate: acceptance_rate,
      categories: categories
    }
  end
end
