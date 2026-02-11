defmodule ElixirNawalaDK168.Workers.CheckDomainWorker do
  use Oban.Worker, queue: :checker, max_attempts: 5

  alias ElixirNawalaDK168.Monitor
  alias ElixirNawalaDK168.Sflink.Client

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"domain_id" => domain_id}}) do
    case Monitor.get_domain(domain_id) do
      nil ->
        :discard

      domain ->
        previous_status = domain.last_status

        with {:ok, result} <- Client.fetch_domain_status(domain.name),
             {:ok, %{domain: updated_domain, changed?: changed?}} <-
               Monitor.record_domain_check(
                 domain,
                 result.status,
                 result.raw_payload,
                 result.latency_ms,
                 result.request_id
               ) do
          Monitor.broadcast_domain_updated(updated_domain)

          if changed? do
            Monitor.enqueue_domain_status_notifications(
              updated_domain,
              previous_status,
              updated_domain.last_status
            )
          end

          :ok
        else
          _ -> {:error, :check_failed}
        end
    end
  end

  def new_job(domain_id) when is_integer(domain_id) do
    %{"domain_id" => domain_id}
    |> Oban.Job.new(
      worker: __MODULE__,
      queue: :checker,
      unique: [
        period: 60,
        fields: [:worker, :args],
        keys: ["domain_id"],
        states: [:available, :scheduled, :executing, :retryable]
      ]
    )
  end
end
