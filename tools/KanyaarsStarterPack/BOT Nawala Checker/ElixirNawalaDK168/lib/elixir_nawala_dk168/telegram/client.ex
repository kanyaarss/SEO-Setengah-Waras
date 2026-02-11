defmodule ElixirNawalaDK168.Telegram.Client do
  @moduledoc false

  @base_url Application.compile_env(:elixir_nawala_dk168, __MODULE__)[:base_url] || "https://api.telegram.org"

  def send_message(chat_id, text) when is_binary(chat_id) and is_binary(text) do
    token = Application.get_env(:elixir_nawala_dk168, __MODULE__)[:bot_token]

    if is_nil(token) or token == "" do
      {:error, :missing_bot_token}
    else
      url = "#{@base_url}/bot#{token}/sendMessage"

      case Req.post(url, json: %{chat_id: chat_id, text: text}) do
        {:ok, %{status: status}} when status in 200..299 -> :ok
        {:ok, %{status: status, body: body}} -> {:error, {:telegram_error, status, body}}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end

