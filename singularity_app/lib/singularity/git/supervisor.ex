defmodule Singularity.Git.Supervisor do
  @moduledoc """
  Supervises the Git tree coordinator when enabled via configuration.

  Configuration (under `:singularity, :git_coordinator`):
    * `:enabled` - boolean flag, defaults to false
    * `:repo_path` - filesystem path for the shared repository (defaults to
      `~/.singularity/git-coordinator` inside the current working directory)
    * `:base_branch` - branch to merge into (defaults to `"main"`)
    * `:remote` - remote name/URL to push to (optional)
  """

  use Supervisor
  require Logger

  alias Singularity.Git.TreeCoordinator

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    config = load_config(opts)

    if enabled?(config) do
      repo_path = repo_path(config)
      File.mkdir_p!(repo_path)

      child =
        {TreeCoordinator,
         repo_path: repo_path,
         base_branch: Keyword.get(config, :base_branch, "main"),
         remote: Keyword.get(config, :remote)}

      Logger.info("Git coordinator enabled",
        repo_path: repo_path,
        base_branch: Keyword.get(config, :base_branch, "main"),
        remote: Keyword.get(config, :remote)
      )

      Supervisor.init([child], strategy: :one_for_one)
    else
      Logger.debug("Git coordinator disabled")
      Supervisor.init([], strategy: :one_for_one)
    end
  end

  @doc "Return whether the git coordinator runtime is enabled."
  def enabled?(config \\ load_config([])) do
    case Keyword.get(config, :enabled, false) do
      truthy when truthy in [true, "true", "1", 1] -> true
      _ -> false
    end
  end

  @doc "Resolve repo path with sensible default."
  def repo_path(config \\ load_config([])) do
    case Keyword.get(config, :repo_path) do
      nil -> default_repo_path()
      path -> Path.expand(path)
    end
  end

  defp load_config(opts) do
    app_config = Application.get_env(:singularity, :git_coordinator, [])
    Keyword.merge(app_config, opts)
  end

  defp default_repo_path do
    Path.join([File.cwd!(), ".singularity", "git-coordinator"])
  end
end
