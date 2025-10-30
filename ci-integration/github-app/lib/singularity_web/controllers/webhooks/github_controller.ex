defmodule SingularityWeb.Webhooks.GithubController do
  use SingularityWeb, :controller
  require Logger

  alias Singularity.{Analysis, Repositories, Github}

  @doc """
  Handles GitHub webhook events for repository analysis.
  """
  def webhook(conn, params) do
    with {:ok, event_type} <- get_event_type(conn),
         {:ok, payload} <- verify_signature(conn, params),
         {:ok, _installation} <- validate_installation(payload) do

      # Process event asynchronously
      Task.start(fn ->
        process_event(event_type, payload)
      end)

      # Respond immediately to GitHub
      conn
      |> put_status(:ok)
      |> json(%{status: "accepted"})
    else
      {:error, reason} ->
        Logger.error("Webhook processing failed: #{inspect(reason)}")
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid webhook"})
    end
  end

  defp get_event_type(conn) do
    case get_req_header(conn, "x-github-event") do
      [event_type] -> {:ok, event_type}
      _ -> {:error, :missing_event_type}
    end
  end

  defp verify_signature(conn, payload) do
    # Verify GitHub webhook signature
    # Implementation depends on your GitHub App configuration
    {:ok, payload}
  end

  defp validate_installation(payload) do
    # Validate that the webhook is from a valid installation
    {:ok, payload["installation"]}
  end

  defp process_event("pull_request", payload) do
    case payload["action"] do
      action when action in ["opened", "synchronize", "reopened"] ->
        handle_pull_request(payload)
      _ ->
        :ok
    end
  end

  defp process_event("push", payload) do
    handle_push(payload)
  end

  defp process_event("installation", payload) do
    handle_installation(payload)
  end

  defp process_event(_event_type, _payload) do
    # Ignore other events
    :ok
  end

  defp handle_pull_request(payload) do
    %{
      "repository" => repo,
      "pull_request" => pr,
      "installation" => %{"id" => installation_id}
    } = payload

    # Queue analysis job
    Analysis.analyze_pull_request(%{
      installation_id: installation_id,
      repo_owner: repo["owner"]["login"],
      repo_name: repo["name"],
      pr_number: pr["number"],
      head_sha: pr["head"]["sha"],
      base_sha: pr["base"]["sha"]
    })
  end

  defp handle_push(payload) do
    %{
      "repository" => repo,
      "after" => commit_sha,
      "installation" => %{"id" => installation_id}
    } = payload

    # Queue analysis job
    Analysis.analyze_commit(%{
      installation_id: installation_id,
      repo_owner: repo["owner"]["login"],
      repo_name: repo["name"],
      commit_sha: commit_sha
    })
  end

  defp handle_installation(payload) do
    case payload["action"] do
      "created" ->
        # Store installation details
        Repositories.create_installation(payload["installation"])
      "deleted" ->
        # Remove installation
        Repositories.delete_installation(payload["installation"]["id"])
      _ ->
        :ok
    end
  end
end