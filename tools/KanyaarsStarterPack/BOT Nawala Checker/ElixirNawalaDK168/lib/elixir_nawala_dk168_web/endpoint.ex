defmodule ElixirNawalaDK168Web.Endpoint do
  use Phoenix.Endpoint, otp_app: :elixir_nawala_dk168

  @session_options [
    store: :cookie,
    key: "_elixir_nawala_dk168_key",
    signing_salt: "LlaFT9Sa",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :elixir_nawala_dk168,
    gzip: false,
    only: ElixirNawalaDK168Web.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :elixir_nawala_dk168
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug ElixirNawalaDK168Web.Router
end

