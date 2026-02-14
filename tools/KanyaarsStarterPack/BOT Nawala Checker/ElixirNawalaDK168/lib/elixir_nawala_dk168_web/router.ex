defmodule ElixirNawalaDK168Web.Router do
  use ElixirNawalaDK168Web, :router

  import ElixirNawalaDK168Web.AdminAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixirNawalaDK168Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_admin
  end

  pipeline :require_admin do
    plug :require_authenticated_admin
  end

  scope "/", ElixirNawalaDK168Web do
    pipe_through :browser

    get "/", PageController, :home
    get "/admin/login", AdminSessionController, :new
    post "/admin/login", AdminSessionController, :create
    get "/admin/logout", AdminSessionController, :delete
    delete "/admin/logout", AdminSessionController, :delete
  end

  scope "/admin", ElixirNawalaDK168Web do
    pipe_through [:browser, :require_admin]

    post "/domains", AdminDomainController, :create
    post "/domains/:id/delete", AdminDomainController, :delete
    live "/dashboard", AdminDashboardLive, :home
    live "/home", AdminDashboardLive, :home
    live "/profile", AdminDashboardLive, :profile
    live "/telegram", AdminDashboardLive, :telegram
    live "/domain/add", AdminDashboardLive, :add_domain
    live "/domain/list", AdminDashboardLive, :list_domain
    live "/domain/status", AdminDashboardLive, :status_domain
  end
end
