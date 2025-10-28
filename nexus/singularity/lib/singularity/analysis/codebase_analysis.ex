defmodule Singularity.CodebaseAnalysis do
  @moduledoc """
  Entry point for working with the codebase analysis schema inside Singularity.

  The modules under `Singularity.Analysis.*` mirror the Rust analysis-suite data
  structures so we can ingest JSON emitted by the Singularity Code Analyzer and persist it
  to Postgres.  Nothing here performs analysis directly; rather it gives BEAM
  services a common schema to work with.
  """

  alias Singularity.Analysis.{Summary, FileReport, Metadata}

  @doc "Decode a JSON payload produced by the Rust analyser into structs."
  @spec decode(binary()) :: {:ok, Summary.t()} | {:error, term()}
  def decode(payload) when is_binary(payload) do
    with {:ok, data} <- Jason.decode(payload) do
      {:ok, Summary.new(data)}
    end
  end

  @doc "Convenience constructor for a single file analysis map."
  @spec file(map()) :: FileReport.t()
  def file(attrs), do: FileReport.new(attrs)

  @doc "Convenience constructor for metadata maps."
  @spec metadata(map()) :: Metadata.t()
  def metadata(attrs), do: Metadata.new(attrs)
end
