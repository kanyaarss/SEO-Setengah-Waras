defmodule ElixirNawalaDK168.Workers.CheckerCycleWorker do
  use Oban.Worker, queue: :checker, max_attempts: 1

  alias ElixirNawalaDK168.Monitor
  alias ElixirNawalaDK168.Workers.CheckDomainWorker

  @impl Oban.Worker
  def perform(_job) do
    domains = Monitor.list_active_domains()

    Enum.each(domains, fn domain ->
      domain.id
      |> CheckDomainWorker.new_job()
      |> Oban.insert()
    end)

    Monitor.broadcast_checker_cycle(%{
      active_domains: length(domains),
      enqueued_at: DateTime.utc_now()
    })

    :ok
  end

  def enqueue do
    %{}
    |> new(unique: [period: 55, fields: [:worker], states: [:available, :scheduled, :executing, :retryable]])
    |> Oban.insert()
  end
end
