defmodule ObserverWeb.AuthController do
  @moduledoc """
  Simple authentication controller for single-user Observer access.
  """

  use ObserverWeb, :controller

  @password System.get_env("OBSERVER_PASSWORD", "admin")

  def login(conn, _params) do
    render(conn, :login)
  end

  def do_login(conn, %{"password" => password}) do
    if password == @password do
      conn
      |> put_session(:authenticated, true)
      |> redirect(to: get_session(conn, :return_to) || "/")
    else
      conn
      |> put_flash(:error, "Invalid password")
      |> render(:login)
    end
  end

  def do_login(conn, _params) do
    conn
    |> put_flash(:error, "Password required")
    |> render(:login)
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: "/login")
  end
end
