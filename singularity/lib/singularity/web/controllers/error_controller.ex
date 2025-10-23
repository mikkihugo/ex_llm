defmodule Singularity.Web.ErrorController do
  @moduledoc """
  Error Controller - Handles HTTP errors and exceptions.

  Provides error handling for:
  - 404 Not Found
  - Other HTTP errors
  - Exception responses
  """

  use Singularity.Web, :controller

  @doc """
  Handle 404 Not Found errors.
  """
  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> json(%{
      error: "Not found",
      status: 404,
      path: conn.request_path,
      method: conn.method,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Render error page for non-API requests.
  """
  def error(conn, _params) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{
      error: "Internal server error",
      status: 500,
      timestamp: DateTime.utc_now()
    })
  end
end
