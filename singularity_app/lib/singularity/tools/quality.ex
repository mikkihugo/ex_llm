defmodule Singularity.Tools.Quality do
  @moduledoc """
  Tool definitions that expose quality checks (Sobelow, mix_audit) via the tool runner.
  """

  alias Singularity.Quality
  alias Singularity.Tools.Tool

  @project_root Path.expand("../../..", __DIR__)

  @doc "Register quality-related tools with the shared registry."
  def register(provider) do
    Singularity.Tools.Singularity.Tools.Catalog.add_tools(provider, [sobelow_tool(), mix_audit_tool()])
  end

  defp sobelow_tool do
    Tool.new!(%{
      name: "quality_sobelow",
      description: "Run Sobelow security scan and store results.",
      display_text: "Sobelow Security Scan",
      parameters: [],
      function: &sobelow_exec/2
    })
  end

  defp mix_audit_tool do
    Tool.new!(%{
      name: "quality_mix_audit",
      description: "Run Hex package vulnerability audit.",
      display_text: "Mix Audit",
      parameters: [],
      function: &mix_audit_exec/2
    })
  end

  def sobelow_exec(_args, _ctx) do
    start_time = DateTime.utc_now()

    {output, status} =
      System.cmd("mix", ["sobelow", "--format", "json"],
        cd: @project_root,
        env: sobelow_env(),
        stderr_to_stdout: true
      )

    finished = DateTime.utc_now()

    case Quality.store_sobelow(%{
           output: output,
           exit_status: status,
           started_at: start_time,
           finished_at: finished
         }) do
      {:ok, run} ->
        {:ok, "Sobelow run completed with #{run.warning_count} warnings"}

      {:error, reason} ->
        {:error, "Failed to store Sobelow results: #{inspect(reason)}"}
    end
  end

  def mix_audit_exec(_args, _ctx) do
    start_time = DateTime.utc_now()

    {output, status} =
      System.cmd("mix", ["deps.audit", "--format", "json"],
        cd: @project_root,
        env: mix_env(),
        stderr_to_stdout: true
      )

    finished = DateTime.utc_now()

    case Quality.store_mix_audit(%{
           output: output,
           exit_status: status,
           started_at: start_time,
           finished_at: finished
         }) do
      {:ok, run} ->
        {:ok, "Mix audit run completed with #{run.warning_count} warnings"}

      {:error, reason} ->
        {:error, "Failed to store mix audit results: #{inspect(reason)}"}
    end
  end

  defp sobelow_env do
    base_env()
  end

  defp mix_env do
    base_env()
  end

  defp base_env do
    [{"MIX_ENV", System.get_env("MIX_ENV", "dev")}]
  end
end
