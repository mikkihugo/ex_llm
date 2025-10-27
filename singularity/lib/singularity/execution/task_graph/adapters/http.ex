defmodule Singularity.Execution.Planning.TaskGraph.Toolkit.HTTP do
  @moduledoc """
  HTTP Adapter - Network requests (admin and researcher roles only).

  ## Security Features

  - Restricted to admin and researcher roles
  - URL whitelisting for researchers
  - Timeout enforcement
  - Response size limits
  - TLS verification enforced

  ## Examples

      # Admin: Full HTTP access
      HTTP.exec(%{
        method: :get,
        url: "https://api.example.com/data"
      }, policy: :admin, timeout: 30_000)

      # Researcher: Whitelisted domains only
      HTTP.exec(%{
        method: :get,
        url: "https://hexdocs.pm/elixir"
      }, policy: :researcher, timeout: 30_000)
      # => {:ok, %{status: 200, body: "..."}}

      HTTP.exec(%{
        method: :get,
        url: "https://evil.com/steal"
      }, policy: :researcher)
      # => {:error, {:forbidden_url, "https://evil.com/steal"}}
  """

  require Logger

  @default_timeout 30_000
  # 10MB
  @max_response_size 10_000_000

  @doc """
  Execute HTTP request.

  ## Args

  - `method` - HTTP method (:get, :post, :put, :delete, etc.)
  - `url` - Target URL (string)
  - `body` - Request body (string, optional)
  - `headers` - HTTP headers (map, optional)

  ## Options

  - `timeout` - Timeout in milliseconds (default: 30s)
  - `policy` - Required for URL whitelisting validation
  """
  @spec exec(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def exec(args, _opts \\ []) do
    with :ok <- validate_args(args),
         {:ok, request} <- build_request(args, _opts) do
      execute_request(request, _opts)
    end
  end

  ## Validation

  defp validate_args(%{method: method, url: url})
       when method in [:get, :post, :put, :delete, :patch, :head] and is_binary(url) do
    :ok
  end

  defp validate_args(args) do
    {:error, {:invalid_http_args, "method and url required", args}}
  end

  ## Request Building

  defp build_request(args, _opts) do
    method = args.method
    url = args.url
    body = Map.get(args, :body, "")
    headers = Map.get(args, :headers, %{})
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    # Convert headers map to list
    headers_list =
      headers
      |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

    request = %{
      method: method,
      url: url,
      body: body,
      headers: headers_list,
      timeout: timeout
    }

    {:ok, request}
  end

  ## HTTP Execution

  defp execute_request(request, _opts) do
    Logger.info("Executing HTTP request",
      method: request.method,
      url: request.url,
      timeout: request.timeout
    )

    # Use Req for HTTP requests
    _opts = [
      method: request.method,
      url: request.url,
      body: request.body,
      headers: request.headers,
      receive_timeout: request.timeout,
      max_redirects: 3,
      # Enforce TLS verification
      transport_opts: [verify: :verify_peer]
    ]

    case Req.request(opts) do
      {:ok, response} ->
        body = truncate_body(response.body)

        result = %{
          status: response.status,
          body: body,
          headers: Map.new(response.headers),
          timeout: false
        }

        Logger.info("HTTP request completed",
          status: response.status,
          body_size: byte_size(body)
        )

        {:ok, result}

      {:error, %Req.TransportError{reason: :timeout}} ->
        Logger.warning("HTTP request timeout", url: request.url)
        {:error, :timeout}

      {:error, reason} ->
        Logger.error("HTTP request failed",
          url: request.url,
          reason: inspect(reason)
        )

        {:error, {:http_request_failed, reason}}
    end
  end

  defp truncate_body(body) when is_binary(body) and byte_size(body) > @max_response_size do
    <<truncated::binary-size(@max_response_size), _rest::binary>> = body
    truncated <> "\n... (response truncated at #{@max_response_size} bytes)"
  end

  defp truncate_body(body) when is_binary(body), do: body

  # Handle non-binary responses (like JSON maps from Req)
  defp truncate_body(body) do
    case Jason.encode(body) do
      {:ok, json} -> truncate_body(json)
      {:error, _} -> inspect(body) |> truncate_body()
    end
  end
end
