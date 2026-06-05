defmodule AutoMyInvoice.Notifications.PushDispatcher do
  @moduledoc """
  Behaviour for delivering a push notification to a single device.

  Live integration (FCM for Android, APNs for iOS) is gated on external
  credentials — a Firebase service account JSON and an APNs auth key —
  that we have not provisioned yet. Until those land, the system runs
  against `LogDispatcher`, which records the would-be push deterministically
  (Logger + an ETS-free in-memory test sink) so the rest of the pipeline
  (device registration, event hooks, fan-out) can be developed and
  regression-tested end-to-end.

  Swap the implementation via:

      config :auto_my_invoice, AutoMyInvoice.Notifications,
        dispatcher: AutoMyInvoice.Notifications.FcmDispatcher
  """

  alias AutoMyInvoice.Notifications.Device

  @typedoc "A push payload: title + body shown to the user, plus optional data."
  @type payload :: %{
          required(:title) => String.t(),
          required(:body) => String.t(),
          optional(:data) => map()
        }

  @callback deliver(device :: Device.t(), payload :: payload()) ::
              {:ok, map()} | {:error, term()}
end
