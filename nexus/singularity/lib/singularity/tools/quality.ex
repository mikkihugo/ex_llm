defmodule Singularity.Tools.Quality do
  @moduledoc """
  Tool definitions that expose quality checks (Sobelow, mix_audit) via the tool runner.
  """

  alias Singularity.Schemas.Tools.Tool

  @project_root Path.expand("../../..", __DIR__)

  @doc "Register quality-related tools with the shared registry."
  def register(provider) do
    Singularity.Tools.Catalog.add_tools(provider, [
      sobelow_tool(),
      mix_audit_tool()
    ])
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

    # Parse JSON output to count warnings
    warning_count =
      case Jason.decode(output) do
        {:ok, %{"warnings" => warnings}} when is_list(warnings) ->
          Enum.count(warnings)

        _ ->
          0
      end

    elapsed_ms = DateTime.diff(finished, start_time, :millisecond)

    {:ok, "Sobelow scan completed in #{elapsed_ms}ms with #{warning_count} warnings (exit: #{status})"}
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

    # Parse JSON output to count vulnerabilities
    vuln_count =
      case Jason.decode(output) do
        {:ok, %{"vulnerabilities" => vulns}} when is_list(vulns) ->
          Enum.count(vulns)

        _ ->
          0
      end

    elapsed_ms = DateTime.diff(finished, start_time, :millisecond)

    {:ok, "Mix audit completed in #{elapsed_ms}ms with #{vuln_count} vulnerabilities (exit: #{status})"}
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
