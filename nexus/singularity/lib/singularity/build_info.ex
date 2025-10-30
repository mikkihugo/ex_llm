defmodule Singularity.BuildInfo do
  @moduledoc """
  Automatic build information - reads from existing sources (VERSION, git, system).

  No config needed - everything is automatic!

  ## Examples

      iex> Singularity.BuildInfo.version()
      "0.1.0"
      
      iex> Singularity.BuildInfo.git_commit()
      "a1b2c3d"
      
      iex> Singularity.BuildInfo.hostname()
      "rtx4080-dev"
      
      iex> Singularity.BuildInfo.github_username()
      "mikkihugo"  # Auto-detected from git config
      
      iex> Singularity.BuildInfo.repo_root()
      "/home/user/code/singularity"  # Auto-detected from git
  """

  require Logger

  @doc "Application version from Mix (reads from VERSION file via mix.exs)"
  def version do
    case Application.spec(:singularity, :vsn) do
      version when is_binary(version) ->
        version

      _ ->
        # Fallback: read VERSION file directly
        root =
          Path.join([__DIR__, "..", "..", "..", "..", "VERSION"])
          |> Path.expand()

        case File.read(root) do
          {:ok, version} -> String.trim(version)
          _ -> "unknown"
        end
    end
  end

  @doc "Git commit SHA (read at runtime, cached)"
  def git_commit do
    case :persistent_term.get(:singularity_git_commit, :not_found) do
      :not_found ->
        sha = read_git_commit()
        :persistent_term.put(:singularity_git_commit, sha)
        sha

      sha ->
        sha
    end
  end

  @doc "Git tag if HEAD is exactly at a tag (read at runtime, cached)"
  def git_tag do
    case :persistent_term.get(:singularity_git_tag, :not_found) do
      :not_found ->
        tag = read_git_tag()
        :persistent_term.put(:singularity_git_tag, tag)
        tag

      tag ->
        tag
    end
  end

  @doc "Hostname from system (auto-detected at runtime)"
  def hostname do
    case System.get_env("HOSTNAME") do
      nil ->
        case :inet.gethostname() do
          {:ok, hostname} -> List.to_string(hostname)
          _ -> System.get_env("COMPUTERNAME") || "unknown"
        end

      hostname ->
        hostname
    end
  end

  @doc "GitHub username/organization (auto-detected from git remote URL)"
  def github_username do
    case :persistent_term.get(:singularity_github_username, :not_found) do
      :not_found ->
        username = detect_github_username()
        :persistent_term.put(:singularity_github_username, username)
        username

      username ->
        username
    end
  end

  @doc "Repository root path (auto-detected from git)"
  def repo_root do
    repo_root = find_repo_root(__DIR__)

    case File.dir?(repo_root) do
      true -> repo_root
      _ -> File.cwd!()
    end
  end

  @doc "Full build info map"
  def info do
    %{
      version: version(),
      git_commit: git_commit(),
      git_tag: git_tag(),
      hostname: hostname(),
      github_username: github_username(),
      repo_root: repo_root()
    }
  end

  defp read_git_commit do
    repo_root = find_repo_root(__DIR__)

    case System.cmd("git", ["rev-parse", "--short", "HEAD"],
           cd: repo_root,
           stderr_to_stdout: true
         ) do
      {sha, 0} -> String.trim(sha)
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end

  defp read_git_tag do
    repo_root = find_repo_root(__DIR__)

    case System.cmd("git", ["describe", "--tags", "--exact-match", "HEAD"],
           cd: repo_root,
           stderr_to_stdout: true
         ) do
      {tag, 0} -> String.trim(tag)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp detect_github_username do
    repo_root = find_repo_root(__DIR__)

    case System.cmd("git", ["remote", "get-url", "origin"], cd: repo_root, stderr_to_stdout: true) do
      {url, 0} ->
        url = String.trim(url)
        # Parse git@github.com:username/repo.git or https://github.com/username/repo.git
        case Regex.run(~r/github\.com[\/:]([^\/]+)/, url) do
          [_, username] -> username
          _ -> nil
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp find_repo_root(start_path) do
    start_path
    |> Path.expand()
    |> Path.split()
    |> Enum.reduce_while(nil, fn _part, acc ->
      current = acc || Path.join(Path.split(start_path))
      git_dir = Path.join(current, ".git")

      if File.exists?(git_dir) or File.dir?(git_dir) do
        {:halt, current}
      else
        parent = Path.dirname(current)

        if parent == current do
          {:halt, nil}
        else
          {:cont, parent}
        end
      end
    end) || Path.expand(start_path)
  end
end
