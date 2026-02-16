defmodule ElixirNawalaDK168Web.AdminSessionController do
  use ElixirNawalaDK168Web, :controller

  alias ElixirNawalaDK168.Accounts
  alias ElixirNawalaDK168Web.AdminAuth

  def new(conn, _params) do
    conn
    |> assign(:hide_topbar, true)
    |> render(:new)
  end

  def create(conn, %{"admin" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_admin(email, password) do
      {:ok, admin} ->
        conn
        |> AdminAuth.log_in_admin(admin)
        |> put_flash(:info, "Login successful.")
        |> redirect(to: "/admin/dashboard")

      :error ->
        conn
        |> assign(:hide_topbar, true)
        |> put_flash(:error, "ERROR DIRECTLY CALL 911 RAKA GANTENG")
        |> render(:new)
    end
  end

  def delete(conn, _params) do
    conn
    |> AdminAuth.log_out_admin()
    |> put_flash(:info, "Logged out.")
    |> redirect(to: "/admin/login")
  end
end
