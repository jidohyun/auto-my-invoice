defmodule AutoMyInvoiceWeb.Api.DeviceController do
  use AutoMyInvoiceWeb, :controller

  alias AutoMyInvoice.Notifications
  alias AutoMyInvoiceWeb.Api.{JsonHelpers, FallbackController}

  action_fallback FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    devices = Notifications.list_user_devices(user.id)

    json(conn, %{
      data: Enum.map(devices, &JsonHelpers.render_device/1),
      meta: %{total: length(devices)}
    })
  end

  def create(conn, %{"device" => device_params}) do
    register(conn, device_params)
  end

  # Mobile clients POST {token, platform} at the top level (no "device" wrapper).
  def create(conn, %{"token" => _} = device_params) do
    register(conn, device_params)
  end

  def delete(conn, %{"token" => token}) do
    user = conn.assigns.current_user

    case Notifications.unregister_device(user.id, token) do
      {:ok, _device} -> conn |> put_status(:no_content) |> text("")
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp register(conn, device_params) do
    user = conn.assigns.current_user

    case Notifications.register_device(user.id, device_params) do
      {:ok, device} ->
        conn
        |> put_status(:created)
        |> json(%{data: JsonHelpers.render_device(device)})

      error ->
        error
    end
  end
end
