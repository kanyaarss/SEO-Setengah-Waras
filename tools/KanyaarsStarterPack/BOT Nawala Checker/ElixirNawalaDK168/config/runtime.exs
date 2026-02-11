import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      Example: ecto://USER:PASS@HOST/DB
      """

  config :elixir_nawala_dk168, ElixirNawalaDK168.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :elixir_nawala_dk168, ElixirNawalaDK168Web.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    server: true
end

telegram_bot_token = System.get_env("TELEGRAM_BOT_TOKEN")
config :elixir_nawala_dk168, ElixirNawalaDK168.Telegram.Client, bot_token: telegram_bot_token

sflink_api_token = System.get_env("SFLINK_API_TOKEN")
config :elixir_nawala_dk168, ElixirNawalaDK168.Sflink.Client, api_token: sflink_api_token
