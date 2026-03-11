defmodule AutoMyInvoiceWeb.PaddleWebhookController do
  use AutoMyInvoiceWeb, :controller

  alias AutoMyInvoice.Payments
  alias AutoMyInvoice.Billing

  @doc """
  POST /api/webhooks/paddle

  Receives Paddle Billing webhook events.
  Verifies HMAC-SHA256 signature, logs the event, and processes it.
  """
  def handle(conn, params) do
    with :ok <- verify_signature(conn),
         {:ok, event} <- log_event(params) do
      process_event(event, params)

      conn
      |> put_status(200)
      |> json(%{status: "ok"})
    else
      {:error, :invalid_signature} ->
        conn |> put_status(403) |> json(%{error: "Invalid signature"})

      {:error, :duplicate_event} ->
        conn |> put_status(200) |> json(%{status: "already_processed"})

      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: inspect(reason)})
    end
  end

  defp verify_signature(conn) do
    secret = Application.get_env(:auto_my_invoice, :paddle_webhook_secret)

    if is_nil(secret) or secret == "" do
      # In development/test, skip signature verification
      :ok
    else
      signature = get_req_header(conn, "paddle-signature") |> List.first()
      verify_paddle_signature(conn, signature, secret)
    end
  end

  defp verify_paddle_signature(_conn, nil, _secret), do: {:error, :invalid_signature}

  defp verify_paddle_signature(conn, signature_header, secret) do
    # Paddle signature format: ts=TIMESTAMP;h1=HASH
    parts =
      signature_header
      |> String.split(";")
      |> Enum.map(&String.split(&1, "=", parts: 2))
      |> Map.new(fn [k, v] -> {k, v} end)

    ts = Map.get(parts, "ts", "")
    h1 = Map.get(parts, "h1", "")

    # Read raw body - must be cached by a plug
    raw_body = conn.assigns[:raw_body] || ""
    signed_payload = "#{ts}:#{raw_body}"

    expected =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(expected, h1) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp log_event(params) do
    event_id = params["event_id"] || Ecto.UUID.generate()
    event_type = params["event_type"] || "unknown"

    # Idempotency check
    case Payments.get_webhook_event(event_id) do
      nil ->
        case Payments.log_webhook_event(%{
               event_id: event_id,
               event_type: event_type,
               payload: params
             }) do
          {:ok, event} -> {:ok, event}
          {:error, _} -> {:error, :duplicate_event}
        end

      _existing ->
        {:error, :duplicate_event}
    end
  end

  defp process_event(event, params) do
    result =
      case params["event_type"] do
        "transaction.completed" ->
          Payments.process_transaction_completed(params["data"] || %{})

        "subscription.created" ->
          Billing.activate_subscription(params["data"] || %{})

        "subscription.updated" ->
          Billing.update_subscription(params["data"] || %{})

        "subscription.canceled" ->
          Billing.cancel_subscription(params["data"] || %{})

        _ ->
          :ok
      end

    case result do
      :ok ->
        Payments.mark_event_processed(event)

      {:error, reason} ->
        Payments.mark_event_failed(event, inspect(reason))
    end
  end
end
