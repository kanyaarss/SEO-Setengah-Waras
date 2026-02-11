defmodule ElixirNawalaDK168.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixirNawalaDK168Web.Telemetry,
      ElixirNawalaDK168.Repo,
      {DNSCluster, query: Application.get_env(:elixir_nawala_dk168, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixirNawalaDK168.PubSub},
      {Finch, name: ElixirNawalaDK168.Finch},
      {Oban, Application.fetch_env!(:elixir_nawala_dk168, Oban)},
      ElixirNawalaDK168.Checker.Scheduler,
      ElixirNawalaDK168Web.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ElixirNawalaDK168.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ElixirNawalaDK168Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
