defmodule Singularity.Schemas.FailurePattern do
  @moduledoc """
  Ecto schema for persisted failure patterns discovered during plan execution.

  The self-evolving pipeline records execution failures together with rich
  metadata (story signature, validation state, root causes, and attempted
  fixes). This dataset powers historical validation, adaptive refinement, and
  continuous rule evolution.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  @typedoc "Stored failure pattern with aggregated metadata"
  @type t :: %FailurePattern{
          id: integer() | nil,
          run_id: String.t(),
          story_type: String.t() | nil,
          story_signature: String.t(),
          failure_mode: String.t(),
          root_cause: String.t() | nil,
          plan_characteristics: map(),
          validation_state: String.t() | nil,
          validation_errors: list(map()),
          execution_error: String.t() | nil,
          frequency: non_neg_integer(),
          successful_fixes: list(map()),
          last_seen_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :id, autogenerate: true}
  schema "failure_patterns" do
    field :run_id, :string
    field :story_type, :string
    field :story_signature, :string
    field :failure_mode, :string
    field :root_cause, :string
    field :plan_characteristics, :map, default: %{}
    field :validation_state, :string
    field :validation_errors, {:array, :map}, default: []
    field :execution_error, :string
    field :frequency, :integer, default: 1
    field :successful_fixes, {:array, :map}, default: []
    field :last_seen_at, :utc_datetime_usec

    timestamps()
  end

  @create_required [:run_id, :story_signature, :failure_mode]
  @cast_fields [
    :run_id,
    :story_type,
    :story_signature,
    :failure_mode,
    :root_cause,
    :plan_characteristics,
    :validation_state,
    :validation_errors,
    :execution_error,
    :frequency,
    :successful_fixes,
    :last_seen_at
  ]

  @doc """
  Base changeset for inserting or updating failure patterns.

  Ensures required fields are present and default collections/maps are
  initialised. `last_seen_at` defaults to the current UTC timestamp when not
  provided.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%FailurePattern{} = pattern, attrs) do
    pattern
    |> cast(attrs, @cast_fields)
    |> validate_required(@create_required)
    |> validate_length(:story_signature, min: 6)
    |> validate_length(:failure_mode, min: 2)
    |> normalize_validation_state()
    |> ensure_map(:plan_characteristics)
    |> ensure_list(:validation_errors)
    |> ensure_list(:successful_fixes)
    |> default_last_seen_at()
    |> clamp_frequency()
  end

  @doc """
  Builds a changeset suitable for incrementing an existing failure pattern.

  The frequency is bumped by `frequency_increment` (default 1) and the last
  seen timestamp is refreshed. Collection/map fields are merged with existing
  data rather than overwritten.
  """
  @spec increment_changeset(t(), map()) :: Ecto.Changeset.t()
  def increment_changeset(%FailurePattern{} = pattern, attrs) do
    {increment, attrs_without_increment} = Map.pop(attrs, :frequency_increment, 1)
    increment = normalize_increment(increment)

    merged_attrs =
      attrs_without_increment
      |> maybe_merge_map(:plan_characteristics, pattern.plan_characteristics)
      |> maybe_merge_list(:successful_fixes, pattern.successful_fixes)
      |> maybe_merge_list(:validation_errors, pattern.validation_errors)
      |> Map.put(:frequency, pattern.frequency + increment)
      |> Map.put(:last_seen_at, DateTime.utc_now())

    changeset(pattern, merged_attrs)
  end

  defp normalize_validation_state(changeset) do
    case fetch_change(changeset, :validation_state) do
      {:ok, state} when is_binary(state) ->
        trimmed = state |> String.trim() |> String.downcase()

        allowed = ["passed", "failed", "skipped", "unknown", ""]

        if trimmed in allowed do
          put_change(changeset, :validation_state, if(trimmed == "", do: nil, else: trimmed))
        else
          add_error(changeset, :validation_state, "must be one of #{Enum.join(allowed, ", ")}")
        end

      _ ->
        changeset
    end
  end

  defp ensure_map(changeset, field) do
    current = get_field(changeset, field) || %{}

    cond do
      is_map(current) ->
        changeset

      true ->
        put_change(changeset, field, %{})
    end
  end

  defp ensure_list(changeset, field) do
    current = get_field(changeset, field) || []

    cond do
      is_list(current) ->
        changeset

      true ->
        put_change(changeset, field, [])
    end
  end

  defp default_last_seen_at(changeset) do
    case get_field(changeset, :last_seen_at) do
      nil -> put_change(changeset, :last_seen_at, DateTime.utc_now())
      _ -> changeset
    end
  end

  defp clamp_frequency(changeset) do
    freq = get_field(changeset, :frequency)

    cond do
      is_integer(freq) and freq >= 1 ->
        changeset

      is_integer(freq) ->
        put_change(changeset, :frequency, 1)

      true ->
        put_change(changeset, :frequency, 1)
    end
  end

  defp normalize_increment(increment) when is_integer(increment) and increment > 0, do: increment
  defp normalize_increment(_), do: 1

  defp maybe_merge_map(attrs, field, original) do
    case Map.fetch(attrs, field) do
      {:ok, map} when is_map(map) ->
        merged = deep_merge(original || %{}, map)
        Map.put(attrs, field, merged)

      _ ->
        attrs
    end
  end

  defp maybe_merge_list(attrs, field, original) do
    case Map.fetch(attrs, field) do
      {:ok, list} when is_list(list) ->
        merged =
          original
          |> List.wrap()
          |> Enum.concat(list)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq_by(&:erlang.term_to_binary/1)

        Map.put(attrs, field, merged)

      _ ->
        attrs
    end
  end

  defp deep_merge(nil, map), do: map
  defp deep_merge(map, nil), do: map

  defp deep_merge(map1, map2) do
    Map.merge(map1, map2, fn _key, value1, value2 ->
      cond do
        is_map(value1) and is_map(value2) -> deep_merge(value1, value2)
        true -> value2
      end
    end)
  end
end
