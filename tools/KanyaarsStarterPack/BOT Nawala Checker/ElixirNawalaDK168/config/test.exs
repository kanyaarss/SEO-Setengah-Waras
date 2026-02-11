import Config

config :elixir_nawala_dk168, ElixirNawalaDK168.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "elixir_nawala_dk168_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :elixir_nawala_dk168, ElixirNawalaDK168Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "QC9uHXGvZXxkH6FK3y4ywM6B7MH0P5s4Ls7kW8O2M2o88o34ZtH4Sg2h9P7v6Jt9",
  server: false

config :elixir_nawala_dk168, ElixirNawalaDK168.Mailer, adapter: Swoosh.Adapters.Test

config :swoosh, :api_client, false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :bcrypt_elixir, :log_rounds, 1
