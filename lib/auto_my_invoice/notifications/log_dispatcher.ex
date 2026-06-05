defmodule AutoMyInvoice.Notifications.LogDispatcher do
  @moduledoc """
  Deterministic stand-in for the push dispatcher. Logs the would-be push
  and returns a synthetic delivery receipt `LOG-<platform>-<unix>` without
  contacting FCM/APNs.

  When a real dispatcher (FCM/APNs) lands, swap via:

      config :auto_my_invoice, AutoMyInvoice.Notifications,
        dispatcher: AutoMyInvoice.Notifications.FcmDispatcher

  The log dispatcher is the default (see `AutoMyInvoice.Notifications.dispatcher/0`).
  """

  @behaviour AutoMyInvoice.Notifications.PushDispatcher

  require Logger

  alias AutoMyInvoice.Notifications.Device

  @impl true
  def deliver(%Device{} = device, %{title: title, body: body} = payload) do
    Logger.info(
      "LogDispatcher: push to #{device.platform} device #{String.slice(device.token, 0, 12)}… " <>
        "title=#{inspect(title)} body=#{inspect(body)}"
    )

    {:ok,
     %{
       receipt: "LOG-#{device.platform}-#{System.system_time(:second)}",
       stub: true,
       token: device.token,
       platform: device.platform,
       data: Map.get(payload, :data, %{})
     }}
  end
end
