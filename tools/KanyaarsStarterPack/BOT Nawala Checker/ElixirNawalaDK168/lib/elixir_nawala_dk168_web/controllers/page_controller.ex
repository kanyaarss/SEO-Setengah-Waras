defmodule ElixirNawalaDK168Web.PageController do
  use ElixirNawalaDK168Web, :controller

  def home(conn, _params) do
    conn
    |> assign(:hide_topbar, true)
    |> assign(:home_gateway, true)
    |> render(:home)
  end
end
