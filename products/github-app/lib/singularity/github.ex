defmodule Singularity.Github do
  @moduledoc """
  GitHub API client for the Singularity App.
  """

  @github_api_base "https://api.github.com"

  @doc """
  Create a GitHub check run.
  """
  def create_check_run(installation_id, owner, repo, params) do
    post("/repos/#{owner}/#{repo}/check-runs", params, installation_id)
  end

  @doc """
  Update a GitHub check run.
  """
  def update_check_run(installation_id, owner, repo, check_run_id, params) do
    patch("/repos/#{owner}/#{repo}/check-runs/#{check_run_id}", params, installation_id)
  end

  @doc """
  Create a pull request comment.
  """
  def create_pr_comment(installation_id, owner, repo, pr_number, params) do
    post("/repos/#{owner}/#{repo}/issues/#{pr_number}/comments", params, installation_id)
  end

  @doc """
  Get repository contents (for analysis).
  """
  def get_repository_archive(installation_id, owner, repo, ref) do
    # Get repository as tarball/zip for analysis
    get("/repos/#{owner}/#{repo}/zipball/#{ref}", installation_id)
  end

  @doc """
  Get installation access token.
  """
  def get_installation_token(installation_id) do
    # Exchange installation ID for access token
    # This requires GitHub App private key
    post("/app/installations/#{installation_id}/access_tokens", %{}, :app)
  end

  @doc """
  Verify webhook signature.
  """
  def verify_webhook_signature(payload, signature, secret) do
    # Verify GitHub webhook signature using HMAC-SHA256
    expected_signature = "sha256=" <> hmac_sha256(payload, secret)

    if Plug.Crypto.secure_compare(signature, expected_signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  # Private API functions

  defp get(path, installation_id) do
    make_request(:get, path, %{}, installation_id)
  end

  defp post(path, params, installation_id) do
    make_request(:post, path, params, installation_id)
  end

  defp patch(path, params, installation_id) do
    make_request(:patch, path, params, installation_id)
  end

  defp make_request(method, path, params, installation_id) do
    url = @github_api_base <> path

    # Get access token for installation
    {:ok, token} = get_installation_token(installation_id)

    headers = [
      {"Authorization", "Bearer #{token["token"]}"},
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "Singularity-GitHub-App/1.0"}
    ]

    case HTTPoison.request(method, url, Jason.encode!(params), headers) do
      {:ok, %HTTPoison.Response{status_code: 200..299, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, %{status: status, body: Jason.decode!(body)}}
      {:error, error} ->
        {:error, error}
    end
  end

  defp hmac_sha256(data, secret) do
    :crypto.mac(:hmac, :sha256, secret, data)
    |> Base.encode16(case: :lower)
  end
end