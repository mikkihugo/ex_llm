defmodule Singularity.TechnologyDetector do
  @moduledoc """
  Backwards-compatible wrapper over `Singularity.Architecture.Detectors.TechnologyDetector`.

  Older parts of the codebase expect functions such as
  `detect_technologies_elixir/2`.  The canonical detector now lives inside the
  architecture engine and exposes a single `detect/2` function that returns a
  list of typed detections.  This module adapts the new API to the legacy one
  without duplicating detection logic.
  """

  alias Singularity.Architecture.Detectors.TechnologyDetector, as: Impl

  @type detection ::
          %{
            name: String.t(),
            type: String.t(),
            confidence: number(),
            description: String.t()
          }

  @doc """
  Compatibility entry point used throughout the older Elixir-focused code paths.

  Returns a tuple with a `:technologies` map that mirrors the old structure
  (`frameworks`, `languages`, `databases`, etc.) while still exposing the raw
  detection list under `:detections`.
  """
  @spec detect_technologies_elixir(Path.t(), keyword()) ::
          {:ok, %{technologies: map(), detections: [detection()]}} | {:error, term()}
  def detect_technologies_elixir(path, opts \\ []) do
    detect(path, opts)
  end

  @doc """
  Modern façade: run technology detection and return normalised results.
  """
  @spec detect(Path.t(), keyword()) ::
          {:ok, %{technologies: map(), detections: [detection()]}} | {:error, term()}
  def detect(path, opts \\ []) when is_binary(path) do
    try do
      detections = Impl.detect(path, opts)
      {:ok, %{technologies: normalise(detections), detections: detections}}
    rescue
      error ->
        {:error, error}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp normalise(detections) do
    detections
    |> Enum.reduce(base_tech_map(), fn detection, acc ->
      type = Map.get(detection, :type) || Map.get(detection, "type") || "technology"
      name = Map.get(detection, :name) || Map.get(detection, "name")

      acc
      |> accumulate(:languages, type, name, ["language"])
      |> accumulate(:frameworks, type, name, ["framework"])
      |> accumulate(:databases, type, name, ["database"])
      |> accumulate(:messaging, type, name, ["messaging"])
      |> accumulate(:caches, type, name, ["cache"])
      |> accumulate(:runtimes, type, name, ["runtime"])
      |> accumulate(:ci_cd, type, name, ["ci_cd"])
      |> accumulate(:containers, type, name, ["container", "container_orchestration"])
      |> accumulate(:service_meshes, type, name, ["service_mesh"])
      |> accumulate(:api_gateways, type, name, ["api_gateway"])
      |> Map.update!(:all, fn list -> [detection | list] end)
    end)
    |> Map.new(fn
      {:all, detections_list} ->
        {:all, Enum.reverse(detections_list)}

      {key, list} ->
        unique =
          list
          |> Enum.reverse()
          |> Enum.uniq()

        {key, unique}
    end)
  end

  defp base_tech_map do
    %{
      languages: [],
      frameworks: [],
      databases: [],
      messaging: [],
      caches: [],
      runtimes: [],
      ci_cd: [],
      containers: [],
      service_meshes: [],
      api_gateways: [],
      all: []
    }
  end

  defp accumulate(acc, key, type, name, accepted_types) do
    cond do
      is_nil(name) ->
        acc

      Enum.member?(accepted_types, type) ->
        Map.update!(acc, key, fn list -> [name | list] end)

      true ->
        acc
    end
  end
end
