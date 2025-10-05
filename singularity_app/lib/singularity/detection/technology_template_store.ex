defmodule Singularity.TechnologyTemplateStore do
  @moduledoc """
  Persistent storage layer for technology detection templates.

  Templates are stored in PostgreSQL so agents can extend or override
  the repository JSON definitions at runtime while keeping validation via
  JSONB constraints.
  """

  import Ecto.{Changeset, Query}

  alias Singularity.Schemas.TechnologyTemplate, as: Template
  alias Singularity.{Repo, TechnologyTemplateLoader}

  @type template_identifier :: atom() | String.t() | [atom() | String.t()] | {atom(), atom()}
  @type template_map :: map()

  @doc """
  Fetch a technology template from the database for the given identifier.
  Returns the decoded template map or `nil` when absent.
  """
  @spec get(template_identifier()) :: template_map() | nil
  def get(identifier) do
    key = normalize_identifier(identifier)

    from(t in Template, where: t.identifier == ^key)
    |> Repo.one()
    |> case do
      %Template{template: template} -> template
      _ -> nil
    end
  end

  @doc """
  Upsert a template, ensuring the JSONB payload is validated and tracked
  with a deterministic checksum. Accepts optional metadata such as source
  or version overrides.
  """
  @spec upsert(template_identifier(), template_map(), keyword()) ::
          {:ok, Template.t()} | {:error, Changeset.t()}
  def upsert(identifier, %{} = template, opts \\ []) do
    key = normalize_identifier(identifier)

    category =
      opts[:category] || category_from_identifier(identifier) || template["category"] || "unknown"

    version = opts[:version] || template["version"] || get_in(template, ["metadata", "version"])
    source = opts[:source] || "seed"
    metadata = opts[:metadata] || %{}
    checksum = compute_checksum(template)

    params = %{
      identifier: key,
      category: category,
      version: version,
      source: source,
      template: template,
      metadata: metadata,
      checksum: checksum
    }

    changeset =
      case Repo.get_by(Template, identifier: key) do
        nil -> %Template{}
        %Template{} = existing -> existing
      end
      |> Template.changeset(params)

    Repo.insert_or_update(changeset)
  end

  @doc """
  Remove all stored templates (useful for resetting during tests).
  """
  def truncate! do
    Repo.delete_all(Template)
    :ok
  end

  @doc """
  Import all JSON templates from the standard directories (or custom ones
  via `opts[:dirs]`) into PostgreSQL. Returns a summary map with counts and
  any errors encountered.
  """
  @spec import_from_directories(keyword()) :: %{upserted: non_neg_integer(), errors: list()}
  def import_from_directories(opts \\ []) do
    dirs = TechnologyTemplateLoader.directories(opts)

    Enum.reduce(dirs, %{upserted: 0, errors: []}, fn dir, acc ->
      if File.dir?(dir) do
        dir
        |> Path.join("**/*.json")
        |> Path.wildcard()
        |> Enum.reduce(acc, fn path, acc ->
          case import_from_path(dir, path, opts) do
            :ok -> %{acc | upserted: acc.upserted + 1}
            {:error, reason} -> %{acc | errors: [{path, reason} | acc.errors]}
          end
        end)
      else
        acc
      end
    end)
  end

  defp import_from_path(root_dir, path, opts) do
    with {:ok, template} <- load_json(path),
         {:ok, identifier} <- identifier_from_path(root_dir, path),
         {:ok, _record} <-
           upsert(identifier, template,
             source: opts[:source] || "filesystem",
             metadata: %{relative_path: Path.relative_to(path, root_dir)}
           ) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp load_json(path) do
    case File.read(path) do
      {:ok, contents} -> Jason.decode(contents)
      {:error, reason} -> {:error, reason}
    end
  end

  defp identifier_from_path(root_dir, path) do
    relative = Path.relative_to(path, root_dir) |> String.trim_leading("/")
    segments = relative |> Path.rootname() |> Path.split()

    identifier =
      case segments do
        [single] -> normalize_segment(single)
        [category, name] -> {normalize_segment(category), normalize_segment(name)}
        _ -> Enum.map(segments, &normalize_segment/1)
      end

    {:ok, identifier}
  rescue
    _ -> {:error, :invalid_identifier}
  end

  defp normalize_segment(segment) do
    segment
    |> String.trim()
    |> String.replace(~r/\s+/, "_")
    |> String.replace(~r/[^a-zA-Z0-9_\-]/, "-")
    |> String.downcase()
    |> String.to_atom()
  end

  @doc false
  def normalize_identifier(identifier) when is_atom(identifier), do: Atom.to_string(identifier)
  def normalize_identifier(identifier) when is_binary(identifier), do: identifier

  def normalize_identifier({category, name}) do
    [category, name]
    |> Enum.map(&normalize_identifier/1)
    |> Enum.join("/")
  end

  def normalize_identifier(list) when is_list(list) do
    list
    |> Enum.map(&normalize_identifier/1)
    |> Enum.join("/")
  end

  defp category_from_identifier({category, _name}) when is_atom(category),
    do: Atom.to_string(category)

  defp category_from_identifier([category | _]) when is_atom(category),
    do: Atom.to_string(category)

  defp category_from_identifier([category | _]) when is_binary(category), do: category

  defp category_from_identifier(identifier) when is_atom(identifier),
    do: Atom.to_string(identifier)

  defp category_from_identifier(identifier) when is_binary(identifier), do: identifier
  defp category_from_identifier(_), do: nil

  defp compute_checksum(template) do
    template
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
