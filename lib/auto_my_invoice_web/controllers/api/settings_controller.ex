defmodule AutoMyInvoiceWeb.Api.SettingsController do
  use AutoMyInvoiceWeb, :controller

  alias AutoMyInvoice.Accounts
  alias AutoMyInvoiceWeb.Api.{JsonHelpers, FallbackController}

  action_fallback FallbackController

  def show(conn, _params) do
    user = conn.assigns.current_user
    json(conn, %{data: JsonHelpers.render_user(user)})
  end

  def update(conn, %{"settings" => settings_params}) do
    user = conn.assigns.current_user

    case Accounts.update_profile(user, settings_params) do
      {:ok, updated} ->
        json(conn, %{data: JsonHelpers.render_user(updated)})

      error ->
        error
    end
  end
end
