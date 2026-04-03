defmodule AutoMyInvoiceWeb.Api.ClientAnalyticsController do
  use AutoMyInvoiceWeb, :controller

  alias AutoMyInvoice.Clients
  alias AutoMyInvoiceWeb.Api.FallbackController

  action_fallback FallbackController

  @doc "GET /api/v1/clients/ranking"
  def ranking(conn, _params) do
    user = conn.assigns.current_user
    ranking = Clients.client_ranking(user.id)

    json(conn, %{data: ranking})
  end

  @doc "GET /api/v1/clients/:id/analytics"
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    _client = Clients.get_client!(user.id, id)
    analytics = Clients.client_analytics(id)

    json(conn, %{data: analytics})
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end
end
