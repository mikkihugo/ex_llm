defmodule Singularity.Detection.ApprovedPatternStore do
  @moduledoc """
  Read-only accessor for replicated CentralCloud `approved_patterns`.

  The table is populated via logical replication. All functions in
  this module are safe to call without guarding for CentralCloud
  availability because the data lives locally inside Singularity's DB.
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.ApprovedPattern

  @type pattern :: ApprovedPattern.t()

  @spec get_by_name(String.t(), keyword()) :: {:ok, pattern()} | {:error, :not_found}
  def get_by_name(name, opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem)

    ApprovedPattern
    |> where([ap], fragment("lower(?)", ap.name) == ^String.downcase(name))
    |> maybe_filter_ecosystem(ecosystem)
    |> order_by([ap], desc: ap.confidence)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      pattern -> {:ok, pattern}
    end
  end

  @spec list_by_ecosystem(String.t()) :: [pattern()]
  def list_by_ecosystem(ecosystem) when is_binary(ecosystem) do
    ApprovedPattern
    |> where([ap], ap.ecosystem == ^ecosystem)
    |> order_by([ap], desc: ap.confidence)
    |> Repo.all()
  end

  @spec all(keyword()) :: [pattern()]
  def all(opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)

    ApprovedPattern
    |> order_by([ap], desc: ap.confidence)
    |> limit(^limit)
    |> Repo.all()
  end

  @spec search(String.t(), keyword()) :: [pattern()]
  def search(query, opts \\ []) when is_binary(query) do
    top_k = Keyword.get(opts, :top_k, 25)
    ecosystem = Keyword.get(opts, :ecosystem)

    ApprovedPattern
    |> where(
      [ap],
      ilike(ap.name, ^"%#{query}%") or ilike(ap.description, ^"%#{query}%")
    )
    |> maybe_filter_ecosystem(ecosystem)
    |> order_by([ap], desc: ap.confidence)
    |> limit(^top_k)
    |> Repo.all()
  end

  defp maybe_filter_ecosystem(query, nil), do: query

  defp maybe_filter_ecosystem(query, ecosystem) do
    where(query, [ap], ap.ecosystem == ^ecosystem)
  end
end
