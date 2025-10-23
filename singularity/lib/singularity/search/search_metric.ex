defmodule Singularity.Search.SearchMetric do
  @moduledoc """
  Search Metric - Track individual search query performance and user satisfaction.

  ## Overview

  Stores metrics for each search query performed, including execution time,
  results returned, user satisfaction ratings, and caching information.

  ## Schema Fields

  - `query` - The search query text
  - `elapsed_ms` - Query execution time in milliseconds
  - `results_count` - Number of results returned
  - `embedding_model` - Which embedding model was used
  - `cache_hit` - Whether result was served from cache
  - `fallback_used` - Whether fallback strategy was invoked
  - `user_satisfaction` - User rating (1-5, optional)
  - `result_index` - Which result was rated (0-based, optional)
  - `rated_at` - When user rated the result (optional)
  - `timestamp` - When the search was performed
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "search_metrics" do
    field :query, :string
    field :elapsed_ms, :integer
    field :results_count, :integer
    field :embedding_model, :string
    field :cache_hit, :boolean, default: false
    field :fallback_used, :boolean, default: false
    field :user_satisfaction, :integer
    field :result_index, :integer
    field :rated_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [
      :query,
      :elapsed_ms,
      :results_count,
      :embedding_model,
      :cache_hit,
      :fallback_used,
      :user_satisfaction,
      :result_index,
      :rated_at
    ])
    |> validate_required([:query, :elapsed_ms, :results_count, :embedding_model])
    |> validate_number(:user_satisfaction, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:result_index, greater_than_or_equal_to: 0)
  end

  @doc """
  Create a new search metric record.
  """
  def create(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset -> {:ok, changeset}
      changeset -> {:error, changeset}
    end
  end
end
