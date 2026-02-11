defmodule ElixirNawalaDK168.Monitor do
  import Ecto.Query, warn: false
  alias ElixirNawalaDK168.Repo
  alias ElixirNawalaDK168.Monitor.{CheckResult, Domain, Notification, Setting, SflinkProfile}
  alias ElixirNawalaDK168.Sflink.Client

  @pubsub ElixirNawalaDK168.PubSub
  @dashboard_topic "monitor:dashboard"

  @settings_defaults %{
    "checker_interval_seconds" => "300",
    "sflink_base_url" => "https://app.sflink.id",
    "sflink_api_token" => "",
    "telegram_group_chat_id" => "",
    "telegram_private_chat_id" => "",
    "telegram_notifications_enabled" => "true"
  }

  def list_domains do
    Domain
    |> order_by([d], asc: d.name)
    |> Repo.all()
  end

  def list_sflink_profiles do
    SflinkProfile
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  def create_sflink_profile(attrs) when is_map(attrs) do
    token =
      attrs
      |> Map.get("api_token", "")
      |> to_string()
      |> String.trim()

    with {:ok, remote} <- Client.get_me_with_token(token) do
      user = remote.user || %{}
      name =
        attrs["name"]
        |> to_string()
        |> String.trim()
        |> case do
          "" -> user["username"] || user["email"] || "SFLINK Profile"
          other -> other
        end

      %SflinkProfile{}
      |> SflinkProfile.changeset(%{
        name: name,
        email: user["email"],
        api_token: token,
        active: false
      })
      |> Repo.insert()
    end
  end

  def activate_sflink_profile(id) when is_integer(id) do
    Repo.transaction(fn ->
      Repo.update_all(SflinkProfile, set: [active: false])

      profile = Repo.get!(SflinkProfile, id)
      {:ok, active_profile} = profile |> SflinkProfile.changeset(%{active: true}) |> Repo.update()

      upsert_settings(%{
        "sflink_base_url" => "https://app.sflink.id",
        "sflink_api_token" => active_profile.api_token
      })

      active_profile
    end)
  end

  def delete_sflink_profile(id) when is_integer(id) do
    Repo.transaction(fn ->
      profile = Repo.get!(SflinkProfile, id)
      is_active = profile.active
      {:ok, _} = Repo.delete(profile)

      if is_active do
        upsert_settings(%{
          "sflink_base_url" => "https://app.sflink.id",
          "sflink_api_token" => ""
        })
      end

      :ok
    end)
  end

  def clear_active_sflink_token do
    Repo.transaction(fn ->
      Repo.update_all(SflinkProfile, set: [active: false])

      upsert_settings(%{"sflink_base_url" => "https://app.sflink.id"})
      clear_setting_key("sflink_api_token")

      :ok
    end)
  end

  def list_remote_domains do
    case Client.list_domains() do
      {:ok, domains} when is_list(domains) ->
        {:ok,
         Enum.map(domains, fn item ->
           %{
             id: item["id"],
             domain: item["domain"] || item["name"],
             status: item["status"],
             is_verified: item["is_verified"],
             created_at: item["created_at"],
             last_checked: item["last_checked"],
             check_interval_minutes: item["check_interval_minutes"]
           }
         end)}

      error ->
        error
    end
  end

  def sync_remote_domains_to_local do
    with {:ok, remote_domains} <- Client.list_domains() do
      Repo.transaction(fn ->
        Enum.reduce(remote_domains, 0, fn item, acc ->
          name = item["domain"] || item["name"]
          remote_id = item["id"]

          if is_binary(name) and is_integer(remote_id) do
            attrs = %{"name" => String.trim(name), "sflink_domain_id" => remote_id}

            case upsert_remote_domain(attrs) do
              :ok -> acc + 1
              _ -> acc
            end
          else
            acc
          end
        end)
      end)
      |> case do
        {:ok, synced_count} -> {:ok, %{synced: synced_count}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def live_check_remote_domain_status(remote_domain_id) when is_integer(remote_domain_id) do
    Client.live_check_status(remote_domain_id)
  end

  def get_remote_profile_stats do
    case Client.get_me() do
      {:ok, %{user: user, stats: stats} = payload} ->
        {:ok, %{user: user || %{}, stats: stats || %{}, raw: payload.raw}}

      error ->
        error
    end
  end

  def get_domain!(id), do: Repo.get!(Domain, id)
  def get_domain(id), do: Repo.get(Domain, id)

  def create_domain(attrs), do: %Domain{} |> Domain.changeset(attrs) |> Repo.insert()

  def create_domain_from_sflink(%{"name" => domain_name} = attrs) when is_binary(domain_name) do
    domain_name = String.trim(domain_name)

    with {:ok, remote_payload} <- Client.create_domain(domain_name) do
      effective_name = remote_payload.domain || domain_name
      remote_id = remote_payload.id

      case Repo.get_by(Domain, name: domain_name) do
        %Domain{} = domain ->
          updated =
            if is_integer(remote_id) and domain.sflink_domain_id != remote_id do
              {:ok, updated_domain} =
                domain
                |> Domain.changeset(%{sflink_domain_id: remote_id})
                |> Repo.update()

              updated_domain
            else
              domain
            end

          {:ok, %{local_domain: updated, sflink: remote_payload}}

        nil ->
          create_attrs =
            attrs
            |> Map.put("name", effective_name)
            |> Map.put("sflink_domain_id", remote_id)

          case create_domain(create_attrs) do
            {:ok, local_domain} -> {:ok, %{local_domain: local_domain, sflink: remote_payload}}
            {:error, reason} -> {:error, reason}
          end
      end
    end
  end

  def delete_domain_from_sflink(local_domain_id) when is_integer(local_domain_id) do
    domain = get_domain!(local_domain_id)

    with {:ok, remote_id} <- resolve_remote_domain_id(domain),
         {:ok, remote_result} <- Client.delete_domain(remote_id),
         {:ok, _local_deleted} <- Repo.delete(domain) do
      {:ok, %{local_name: domain.name, remote_id: remote_id, sflink: remote_result}}
    end
  end

  def delete_remote_domain(remote_domain_id) when is_integer(remote_domain_id) do
    with {:ok, remote_result} <- Client.delete_domain(remote_domain_id) do
      local_deleted =
        case Repo.get_by(Domain, sflink_domain_id: remote_domain_id) do
          nil ->
            false

          %Domain{} = local_domain ->
            case Repo.delete(local_domain) do
              {:ok, _} -> true
              _ -> false
            end
        end

      {:ok, %{remote_id: remote_domain_id, local_deleted: local_deleted, sflink: remote_result}}
    end
  end

  def list_active_domains do
    Domain
    |> where([d], d.active == true)
    |> order_by([d], asc: d.name)
    |> Repo.all()
  end

  def toggle_domain(domain_id) do
    domain = get_domain!(domain_id)
    domain |> Domain.changeset(%{active: !domain.active}) |> Repo.update()
  end

  def list_settings do
    settings = Repo.all(Setting) |> Map.new(&{&1.key, &1.value})
    Map.merge(@settings_defaults, settings)
  end

  def checker_interval_seconds do
    list_settings()
    |> Map.get("checker_interval_seconds", "300")
    |> case do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {seconds, _} when seconds >= 60 -> seconds
          _ -> 300
        end

      _ ->
        300
    end
  end

  def upsert_settings(attrs) when is_map(attrs) do
    Repo.transaction(fn ->
      Enum.each(attrs, fn {key, value} ->
        case Repo.get_by(Setting, key: key) do
          nil ->
            %Setting{} |> Setting.changeset(%{key: key, value: value}) |> Repo.insert!()

          %Setting{} = setting ->
            setting |> Setting.changeset(%{value: value}) |> Repo.update!()
        end
      end)
    end)
  end

  def create_check_result(attrs), do: %CheckResult{} |> CheckResult.changeset(attrs) |> Repo.insert()

  def record_domain_check(%Domain{} = domain, status, raw_payload, latency_ms, request_id) do
    checked_at = DateTime.utc_now()

    Repo.transaction(fn ->
      {:ok, _check_result} =
        create_check_result(%{
          domain_id: domain.id,
          status: status,
          raw_payload: raw_payload,
          checked_at: checked_at,
          latency_ms: latency_ms,
          request_id: request_id
        })

      {:ok, updated_domain} =
        domain
        |> Domain.changeset(%{last_status: status, last_checked_at: checked_at})
        |> Repo.update()

      %{domain: updated_domain, changed?: domain.last_status != status}
    end)
  end

  def create_notification(attrs), do: %Notification{} |> Notification.changeset(attrs) |> Repo.insert()

  def update_notification_status(notification_id, status) when status in ["sent", "failed"] do
    case Repo.get(Notification, notification_id) do
      nil ->
        :ok

      %Notification{} = notification ->
        attrs =
          if status == "sent",
            do: %{status: status, sent_at: DateTime.utc_now()},
            else: %{status: status}

        notification
        |> Notification.changeset(attrs)
        |> Repo.update()
    end
  end

  def enqueue_domain_status_notifications(%Domain{} = domain, previous_status, new_status) do
    settings = list_settings()

    if settings["telegram_notifications_enabled"] == "true" do
      message = "[ElixirNawalaDK168] #{domain.name} berubah: #{previous_status} -> #{new_status}"

      maybe_queue_telegram(:group, settings["telegram_group_chat_id"], domain.id, message)
      maybe_queue_telegram(:private, settings["telegram_private_chat_id"], domain.id, message)
    else
      :ok
    end
  end

  def enqueue_telegram_notification(target, message) when target in [:group, :private] do
    ElixirNawalaDK168.Workers.TelegramMessageWorker.new(%{
      "target" => Atom.to_string(target),
      "message" => message
    })
    |> Oban.insert()
  end

  def subscribe_dashboard, do: Phoenix.PubSub.subscribe(@pubsub, @dashboard_topic)

  def broadcast_domain_updated(%Domain{} = domain) do
    Phoenix.PubSub.broadcast(@pubsub, @dashboard_topic, {:domain_updated, domain})
  end

  def broadcast_checker_cycle(summary) when is_map(summary) do
    Phoenix.PubSub.broadcast(@pubsub, @dashboard_topic, {:checker_cycle_finished, summary})
  end

  defp maybe_queue_telegram(_target, chat_id, _domain_id, _message) when chat_id in [nil, ""], do: :ok

  defp maybe_queue_telegram(target, chat_id, domain_id, message) do
    with {:ok, notification} <-
           create_notification(%{
             domain_id: domain_id,
             channel: "telegram_#{target}",
             event_type: "status_changed",
             payload: %{"chat_id" => chat_id, "message" => message},
             status: "queued"
           }) do
      ElixirNawalaDK168.Workers.TelegramMessageWorker.new(%{
        "target" => Atom.to_string(target),
        "message" => message,
        "notification_id" => notification.id
      })
      |> Oban.insert()
    end
  end

  defp resolve_remote_domain_id(%Domain{sflink_domain_id: id}) when is_integer(id), do: {:ok, id}

  defp resolve_remote_domain_id(%Domain{name: domain_name}) do
    with {:ok, remote_domains} <- Client.list_domains() do
      normalized = String.downcase(domain_name)

      match =
        Enum.find(remote_domains, fn item ->
          remote_name = item["domain"] || item["name"] || item["domain_name"] || ""
          String.downcase(to_string(remote_name)) == normalized
        end)

      case match do
        %{"id" => id} when is_integer(id) -> {:ok, id}
        _ -> {:error, :remote_domain_not_found}
      end
    end
  end

  defp upsert_remote_domain(%{"name" => name, "sflink_domain_id" => remote_id} = attrs) do
    existing =
      Repo.get_by(Domain, sflink_domain_id: remote_id) ||
        Repo.get_by(Domain, name: name)

    case existing do
      nil ->
        case create_domain(attrs) do
          {:ok, _} -> :ok
          _ -> :error
        end

      %Domain{} = domain ->
        update_attrs = %{"name" => name, "sflink_domain_id" => remote_id}

        case domain |> Domain.changeset(update_attrs) |> Repo.update() do
          {:ok, _} -> :ok
          _ -> :error
        end
    end
  end

  defp clear_setting_key(key) when is_binary(key) do
    case Repo.get_by(Setting, key: key) do
      nil -> :ok
      %Setting{} = setting ->
        case Repo.delete(setting) do
          {:ok, _} -> :ok
          _ -> :ok
        end
    end
  end
end
