defmodule AutoMyInvoiceWeb.Api.ReminderAnalyticsController do
  use AutoMyInvoiceWeb, :controller

  alias AutoMyInvoice.Reminders

  @doc "GET /api/v1/analytics/reminders"
  def index(conn, _params) do
    user = conn.assigns.current_user
    effectiveness = Reminders.reminder_effectiveness(user.id)

    json(conn, %{data: effectiveness})
  end
end
