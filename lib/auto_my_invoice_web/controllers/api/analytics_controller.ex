defmodule AutoMyInvoiceWeb.Api.AnalyticsController do
  use AutoMyInvoiceWeb, :controller

  alias AutoMyInvoice.Analytics

  def dashboard(conn, params) do
    user = conn.assigns.current_user
    months = params |> Map.get("months", "6") |> String.to_integer() |> min(24) |> max(1)

    json(conn, %{
      data: %{
        monthly_collections: Analytics.monthly_collections(user.id, months),
        status_distribution: Analytics.status_distribution(user.id),
        invoice_aging: Analytics.invoice_aging(user.id)
      }
    })
  end

  def cashflow(conn, params) do
    user = conn.assigns.current_user
    days = params |> Map.get("days", "90") |> String.to_integer() |> min(365) |> max(1)

    json(conn, %{
      data: %{
        forecast: Analytics.cashflow_forecast(user.id, days)
      }
    })
  end
end
