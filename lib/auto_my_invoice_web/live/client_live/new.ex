defmodule AutoMyInvoiceWeb.ClientLive.New do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Clients.Client

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("새 거래처"))
     |> assign(:client, %Client{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title={gettext("새 거래처")}>
      <:actions>
        <.link navigate={~p"/clients"} class="btn btn-ghost btn-sm">{gettext("← 목록")}</.link>
      </:actions>
    </.page_header>

    <div class="card bg-base-100 shadow max-w-2xl">
      <div class="card-body">
        <.live_component
          module={AutoMyInvoiceWeb.ClientLive.FormComponent}
          id="new-client"
          client={@client}
          action={:new}
          current_user={@current_user}
        />
      </div>
    </div>
    """
  end
end
