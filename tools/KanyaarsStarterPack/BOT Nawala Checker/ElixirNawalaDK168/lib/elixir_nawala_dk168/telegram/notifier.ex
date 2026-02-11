defmodule ElixirNawalaDK168.Telegram.Notifier do
  alias ElixirNawalaDK168.Monitor
  alias ElixirNawalaDK168.Telegram.Client

  def send_test_message(:group, text), do: deliver("telegram_group_chat_id", text)
  def send_test_message(:private, text), do: deliver("telegram_private_chat_id", text)

  def send_domain_status(domain_name, status) do
    msg = "[ElixirNawalaDK168] #{domain_name} => #{status}"
    with :ok <- maybe_deliver("telegram_group_chat_id", msg), :ok <- maybe_deliver("telegram_private_chat_id", msg), do: :ok
  end

  defp maybe_deliver(key, text) do
    settings = Monitor.list_settings()

    if settings["telegram_notifications_enabled"] == "true" and settings[key] != "" do
      Client.send_message(settings[key], text)
    else
      :ok
    end
  end

  defp deliver(key, text) do
    chat_id = Monitor.list_settings()[key]

    if chat_id in [nil, ""] do
      {:error, :missing_chat_id}
    else
      Client.send_message(chat_id, text)
    end
  end
end

