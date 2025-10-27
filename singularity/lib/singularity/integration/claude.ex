defmodule Singularity.Integration.Claude do
  @moduledoc """
  Emergency Claude CLI Integration - Direct local Claude calls for recovery.

  ⚠️  EMERGENCY FALLBACK ONLY ⚠️

  This module provides direct access to Claude via the CLI when:
  - pgmq AI server is down
  - Emergency agent recovery is needed
  - System is in critical failure state

  ## Normal Usage (Preferred)

  For regular LLM calls, always use:

      Singularity.LLM.Service.call(:complex, messages, task_type: :architect)

  This goes through: Elixir → pgmq → TypeScript AI Server → LLM Providers

  ## Emergency Usage (Fallback Only)

  Only use this when pgmq is unavailable:

      Singularity.Integration.Claude.chat(prompt, profile: :recovery)

  ## Profiles

  - `:recovery` - Read-only, safe recovery mode
  - `:analyze` - Analysis mode with file reading
  - `:fix` - Can suggest fixes but not auto-apply

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Integration.Claude",
    "purpose": "Emergency Claude CLI fallback when pgmq is down",
    "role": "emergency_fallback",
    "layer": "integration",
    "criticality": "MEDIUM",
    "use_case": "System recovery only",
    "prevents_duplicates": ["Direct Claude calls", "CLI Claude integration"],
    "relationships": {
      "LLM.Service": "Primary path (preferred)",
      "SelfImprovingAgent": "Uses for emergency recovery",
      "EmergencyLLM": "Exposes Claude CLI as tool"
    }
  }
  ```

  ### Anti-Patterns
  - ❌ **DO NOT** use for regular LLM calls - use LLM.Service
  - ❌ **DO NOT** bypass pgmq for performance - embrace async messaging
  - ✅ **DO** use only in confirmed pgmq failure scenarios
  """

  require Logger

  @type profile :: :recovery | :analyze | :fix
  @type response :: %{response: String.t()} | %{raw: String.t()}

  @doc """
  List available CLI profiles for emergency Claude access.

  Returns a map of profile → configuration.
  """
  @spec available_profiles() :: map()
  def available_profiles do
    %{
      recovery: %{
        description: "Read-only recovery mode - safe for emergency agent operations",
        flags: "--recovery-mode"
      },
      analyze: %{
        description: "Analysis mode - can read files and analyze code",
        flags: "--analyze-mode"
      },
      fix: %{
        description: "Fix suggestion mode - proposes solutions without auto-apply",
        flags: "--suggest-fixes"
      }
    }
  end

  @doc """
  Call Claude via local CLI for emergency/recovery scenarios.

  Returns `{:ok, response}` or `{:error, reason}`.

  ## Examples

      iex> Claude.chat("What went wrong?", profile: :recovery)
      {:ok, %{response: "Analysis of issue..."}}

      iex> Claude.chat("Fix this bug", profile: :fix)
      {:error, "Claude CLI not available"}
  """
  @spec chat(String.t(), Keyword.t()) :: {:ok, response()} | {:error, String.t()}
  def chat(prompt, opts \\ []) when is_binary(prompt) do
    profile = Keyword.get(opts, :profile, :recovery)

    # Check if Claude CLI is available
    case System.cmd("which", ["claude"], stderr_to_stdout: true) do
      {_output, 0} ->
        # Claude CLI is available - call it
        call_claude_cli(prompt, profile)

      {_output, _} ->
        # Claude CLI not found
        Logger.warning("Claude CLI not available for emergency recovery",
          profile: profile
        )

        {:error, "Claude CLI not found in PATH"}
    end
  end

  # ===========================
  # Internal CLI Invocation
  # ===========================

  defp call_claude_cli(prompt, profile) do
    Logger.info("Emergency Claude CLI call", profile: profile)

    try do
      # Create temp file for prompt
      {:ok, temp_file} = Temp.path()
      File.write!(temp_file, prompt)

      # Build Claude CLI command
      cmd = build_claude_command(profile, temp_file)

      # Execute with timeout
      case System.cmd("sh", ["-c", cmd],
             stderr_to_stdout: true,
             timeout: 30_000
           ) do
        {output, 0} ->
          # Success
          cleanup_temp(temp_file)
          {:ok, %{response: String.trim(output)}}

        {error_output, exit_code} ->
          # Failure
          cleanup_temp(temp_file)

          Logger.error("Claude CLI error",
            profile: profile,
            exit_code: exit_code,
            error: error_output
          )

          {:error, "Claude CLI failed with code #{exit_code}: #{error_output}"}
      end
    rescue
      error ->
        Logger.error("Emergency Claude CLI exception", error: inspect(error))
        error_msg = if is_exception(error), do: Exception.message(error), else: inspect(error)
        {:error, "Exception calling Claude CLI: #{error_msg}"}
    end
  end

  defp build_claude_command(profile, temp_file) do
    profile_flags = available_profiles()[profile][:flags] || ""

    # Build safe Claude CLI command
    "claude #{profile_flags} < #{temp_file}"
  end

  defp cleanup_temp(path) do
    File.rm(path)
  catch
    _, _ -> :ok
  end
end
