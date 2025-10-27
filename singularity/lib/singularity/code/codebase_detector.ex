defmodule Singularity.Code.CodebaseDetector do
  @moduledoc """
  Codebase Detector - Auto-detect codebase ID from Git repository.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Code.CodebaseDetector",
    "purpose": "Auto-detect codebase_id from Git remote URL",
    "layer": "infrastructure",
    "used_by": ["StartupCodeIngestion", "CodeFileWatcher", "UnifiedIngestionService"]
  }
  ```

  ## Why This Exists

  Instead of hardcoding `codebase_id = "singularity"`, we auto-detect from Git:

  - ✅ Works for any repo (singularity, singularity-incubation, my-project)
  - ✅ No configuration needed
  - ✅ Consistent naming across system
  - ✅ Matches GitHub repo name

  ## Examples

      iex> CodebaseDetector.detect()
      "singularity-incubation"

      iex> CodebaseDetector.detect(fallback: "my-app")
      "singularity-incubation"  # or "my-app" if Git fails

  ## How It Works

  1. Runs `git remote get-url origin`
  2. Extracts repo name from URL
  3. Falls back to configured default if Git unavailable
  """

  require Logger

  # Cache detection result in ETS for performance
  @cache_table :codebase_detector_cache
  # 5 minutes default
  @default_cache_ttl :timer.minutes(5)
  # 30 minutes during heavy ingestion
  @extended_cache_ttl :timer.minutes(30)

  # Initialize cache table on module load
  def __on_load__ do
    # Create ETS table if it doesn't exist
    unless :ets.whereis(@cache_table) != :undefined do
      :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end

  @doc """
  Detect codebase ID from Git repository.

  ## Parameters

  - `_opts` - Options
    - `:fallback` - Fallback codebase_id if Git detection fails (default: "singularity")
    - `:format` - Format for codebase_id (default: `:repo_only`)
      - `:repo_only` - Just repo name: "singularity-incubation"
      - `:full` - Include owner: "anthropics/singularity-incubation"
    - `:cache_ttl` - Cache TTL in milliseconds (default: 5 minutes, extended to 30 minutes during heavy ingestion)
    - `:extend_cache` - If true, extends cache TTL for heavy ingestion (default: false)

  ## Returns

  - Codebase ID string

  ## Examples

      # Auto-detect from Git (repo only)
      codebase_id = CodebaseDetector.detect()
      # => "singularity-incubation"

      # Include owner/org
      codebase_id = CodebaseDetector.detect(format: :full)
      # => "anthropics/singularity-incubation"

      # With custom fallback
      codebase_id = CodebaseDetector.detect(fallback: "my-project")

      # Extend cache during heavy ingestion (e.g., startup with 933 files)
      codebase_id = CodebaseDetector.detect(format: :full, extend_cache: true)
      # => Cache valid for 30 minutes instead of 5
  """
  def detect(_opts \\ []) do
    fallback = Keyword.get(opts, :fallback, "singularity")
    format = Keyword.get(opts, :format, :repo_only)
    use_cache = Keyword.get(opts, :cache, true)
    extend_cache = Keyword.get(opts, :extend_cache, false)

    # Determine TTL based on extend_cache flag
    cache_ttl =
      if extend_cache do
        @extended_cache_ttl
      else
        Keyword.get(opts, :cache_ttl, @default_cache_ttl)
      end

    # Try cache first
    if use_cache do
      case get_from_cache(format, cache_ttl) do
        {:ok, cached_id} ->
          cached_id

        :miss ->
          detect_and_cache(format, fallback, cache_ttl)
      end
    else
      detect_and_cache(format, fallback, cache_ttl)
    end
  end

  defp detect_and_cache(format, fallback, cache_ttl) do
    case detect_from_git(format: format) do
      {:ok, codebase_id} when is_binary(codebase_id) and codebase_id != "" ->
        put_in_cache(format, codebase_id, cache_ttl)
        codebase_id

      {:error, reason} ->
        Logger.debug(
          "[CodebaseDetector] Git detection failed (#{reason}), using fallback: #{fallback}"
        )

        # Cache fallback too (so we don't keep retrying Git if it's broken)
        put_in_cache(format, fallback, cache_ttl)
        fallback
    end
  end

  defp get_from_cache(format, cache_ttl) do
    cache_key = {:codebase_id, format}

    try do
      case :ets.lookup(@cache_table, cache_key) do
        [{^cache_key, codebase_id, cached_at, _ttl}] ->
          # Check if cache is still valid
          age_ms = System.monotonic_time(:millisecond) - cached_at

          if age_ms < cache_ttl do
            {:ok, codebase_id}
          else
            # Expired
            :ets.delete(@cache_table, cache_key)
            :miss
          end

        [] ->
          :miss
      end
    rescue
      _ ->
        # ETS table not ready yet
        :miss
    end
  end

  defp put_in_cache(format, codebase_id, cache_ttl) do
    cache_key = {:codebase_id, format}
    cached_at = System.monotonic_time(:millisecond)

    try do
      # Store with TTL for observability
      :ets.insert(@cache_table, {cache_key, codebase_id, cached_at, cache_ttl})

      ttl_minutes = div(cache_ttl, 60_000)

      Logger.debug(
        "[CodebaseDetector] Cached #{codebase_id} (format: #{format}, TTL: #{ttl_minutes}min)"
      )
    rescue
      _ ->
        # ETS not ready, skip caching
        :ok
    end
  end

  @doc """
  Detect codebase ID from Git remote URL.

  ## Parameters

  - `_opts` - Options
    - `:format` - Format for codebase_id (default: `:repo_only`)
      - `:repo_only` - Just repo name: "singularity-incubation"
      - `:full` - Include owner: "mikkihugo/singularity-incubation"

  ## Returns

  - `{:ok, codebase_id}` - Successfully detected
  - `{:error, reason}` - Git command failed

  ## Examples

      iex> CodebaseDetector.detect_from_git()
      {:ok, "singularity-incubation"}

      iex> CodebaseDetector.detect_from_git(format: :full)
      {:ok, "mikkihugo/singularity-incubation"}
  """
  def detect_from_git(_opts \\ []) do
    format = Keyword.get(opts, :format, :repo_only)

    case System.cmd("git", ["remote", "get-url", "origin"], stderr_to_stdout: true) do
      {output, 0} ->
        codebase_id = extract_repo_name(output, format)
        {:ok, codebase_id}

      {error, _exit_code} ->
        {:error, "Git command failed: #{String.trim(error)}"}
    end
  rescue
    error ->
      {:error, "Git detection error: #{Exception.message(error)}"}
  end

  @doc """
  Extract repository name from Git remote URL.

  Supports various Git URL formats:
  - HTTPS: https://github.com/user/repo.git
  - SSH: git@github.com:user/repo.git
  - Plain: user/repo

  ## Parameters

  - `git_url` - Git remote URL
  - `format` - Format to return (default: `:repo_only`)
    - `:repo_only` - Just repo name: "singularity-incubation"
    - `:full` - Include owner: "mikkihugo/singularity-incubation"

  ## Examples

      iex> CodebaseDetector.extract_repo_name("https://github.com/mikkihugo/my-repo.git")
      "my-repo"

      iex> CodebaseDetector.extract_repo_name("https://github.com/mikkihugo/my-repo.git", :full)
      "mikkihugo/my-repo"

      iex> CodebaseDetector.extract_repo_name("git@github.com:mikkihugo/my-repo.git")
      "my-repo"

      iex> CodebaseDetector.extract_repo_name("git@github.com:mikkihugo/my-repo.git", :full)
      "mikkihugo/my-repo"
  """
  def extract_repo_name(git_url, format \\ :repo_only) when is_binary(git_url) do
    # Clean URL
    cleaned =
      git_url
      |> String.trim()
      # Remove .git suffix
      |> String.replace(~r/\.git$/, "")

    # Extract owner/repo parts
    parts =
      case cleaned do
        # SSH format: git@github.com:owner/repo
        "git@" <> rest ->
          rest
          |> String.split(":", parts: 2)
          |> List.last()
          |> String.split("/")
          # Last 2 parts: [owner, repo]
          |> Enum.take(-2)

        # HTTPS format: https://github.com/owner/repo
        _ ->
          cleaned
          |> String.split("/")
          # Last 2 parts: [owner, repo]
          |> Enum.take(-2)
      end

    case {parts, format} do
      {[owner, repo], :full} ->
        "#{owner}/#{repo}"

      {[_owner, repo], :repo_only} ->
        repo

      # Fallback if parsing fails
      {[single], _} ->
        single

      _ ->
        cleaned
    end
  end

  @doc """
  Get the full Git remote URL.

  ## Returns

  - `{:ok, url}` - Git remote URL
  - `{:error, reason}` - Git command failed

  ## Examples

      iex> CodebaseDetector.get_remote_url()
      {:ok, "https://github.com/user/repo.git"}
  """
  def get_remote_url do
    case System.cmd("git", ["remote", "get-url", "origin"], stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {error, _exit_code} ->
        {:error, "Git command failed: #{String.trim(error)}"}
    end
  rescue
    error ->
      {:error, "Git detection error: #{Exception.message(error)}"}
  end

  @doc """
  Check if current directory is a Git repository.

  ## Returns

  - `true` - Is a Git repo
  - `false` - Not a Git repo

  ## Examples

      iex> CodebaseDetector.git_repo?()
      true
  """
  def git_repo? do
    case System.cmd("git", ["rev-parse", "--git-dir"], stderr_to_stdout: true) do
      {_output, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Get codebase info including Git metadata.

  ## Returns

  - Map with codebase metadata

  ## Examples

      iex> CodebaseDetector.get_info()
      %{
        codebase_id: "singularity-incubation",
        git_repo: true,
        remote_url: "https://github.com/user/repo.git",
        detected_at: ~U[2025-10-23 16:30:00Z]
      }
  """
  def get_info do
    %{
      codebase_id: detect(),
      git_repo: git_repo?(),
      remote_url:
        case get_remote_url() do
          {:ok, url} -> url
          {:error, _} -> nil
        end,
      detected_at: DateTime.utc_now()
    }
  end

  @doc """
  Clear detection cache (forces re-detection on next call).

  Useful when Git remote changes or for hot-reload scenarios.

  ## Examples

      iex> CodebaseDetector.clear_cache()
      :ok

      # Next detect() call will re-run Git detection
      iex> CodebaseDetector.detect()
      "new-repo-name"
  """
  def clear_cache do
    try do
      :ets.delete_all_objects(@cache_table)
      Logger.debug("[CodebaseDetector] Cache cleared - next detection will query Git")
      :ok
    rescue
      _ ->
        # ETS not ready
        :ok
    end
  end

  @doc """
  Reload codebase detection (clear cache and re-detect).

  Returns the newly detected codebase_id.

  ## Examples

      iex> CodebaseDetector.reload()
      {:ok, "mikkihugo/singularity-incubation"}
  """
  def reload(_opts \\ []) do
    clear_cache()
    codebase_id = detect(Keyword.put(opts, :cache, false))
    {:ok, codebase_id}
  end
end
