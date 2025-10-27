defmodule ObserverWeb.AuthControllerTest do
  use ObserverWeb.ConnCase

  test "GET /login", %{conn: conn} do
    conn = get(conn, ~p"/login")
    assert html_response(conn, 200) =~ "Observer Login"
  end

  test "POST /login with correct password", %{conn: conn} do
    conn = post(conn, ~p"/login", %{"password" => "admin"})
    assert redirected_to(conn) == "/"
    assert get_session(conn, :authenticated) == true
  end

  test "POST /login with incorrect password", %{conn: conn} do
    conn = post(conn, ~p"/login", %{"password" => "wrong"})
    assert html_response(conn, 200) =~ "Invalid password"
    assert get_session(conn, :authenticated) == nil
  end

  test "DELETE /logout", %{conn: conn} do
    conn = 
      conn
      |> put_session(:authenticated, true)
      |> delete(~p"/logout")
    
    assert redirected_to(conn) == "/login"
    assert get_session(conn, :authenticated) == nil
  end
end
