defmodule AutoMyInvoiceWeb.ClientLive.FormComponent do
  use AutoMyInvoiceWeb, :live_component

  alias AutoMyInvoice.Clients
  alias AutoMyInvoice.Clients.Client

  # {label, value} tuples for options_for_select. The value MUST be a valid IANA
  # timezone identifier (e.g. "Asia/Seoul"), because it is stored on the client
  # and passed straight to DateTime.from_naive/2 when scheduling reminders. The
  # human-readable abbreviation belongs in the label only.
  @timezones [
    {"UTC", "UTC"},
    {"Asia/Seoul (KST)", "Asia/Seoul"},
    {"Asia/Tokyo (JST)", "Asia/Tokyo"},
    {"America/New_York (EST)", "America/New_York"},
    {"America/Los_Angeles (PST)", "America/Los_Angeles"},
    {"America/Chicago (CST)", "America/Chicago"},
    {"Europe/London (GMT)", "Europe/London"},
    {"Europe/Paris (CET)", "Europe/Paris"},
    {"Europe/Berlin (CET)", "Europe/Berlin"},
    {"Australia/Sydney (AEST)", "Australia/Sydney"}
  ]

  @impl true
  def update(%{client: client} = assigns, socket) do
    changeset = Client.changeset(client, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:timezones, @timezones)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"client" => client_params}, socket) do
    changeset =
      socket.assigns.client
      |> Client.changeset(client_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"client" => client_params}, socket) do
    save_client(socket, socket.assigns.action, client_params)
  end

  defp save_client(socket, :new, client_params) do
    user = socket.assigns.current_user

    case Clients.create_client(user.id, client_params) do
      {:ok, client} ->
        {:noreply,
         socket
         |> put_flash(:info, "거래처가 생성되었습니다")
         |> push_navigate(to: ~p"/clients/#{client.id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_client(socket, :edit, client_params) do
    case Clients.update_client(socket.assigns.client, client_params) do
      {:ok, client} ->
        {:noreply,
         socket
         |> put_flash(:info, "거래처가 수정되었습니다")
         |> push_navigate(to: ~p"/clients/#{client.id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="client-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label={gettext("이름")} required />
        <.input field={@form[:email]} type="email" label={gettext("이메일")} required />
        <.input field={@form[:company]} type="text" label={gettext("회사명")} />
        <.input field={@form[:phone]} type="tel" label={gettext("전화번호")} />
        <.input field={@form[:address]} type="text" label={gettext("주소")} />
        <.input
          field={@form[:timezone]}
          type="select"
          label={gettext("시간대")}
          options={@timezones}
        />
        <.input field={@form[:notes]} type="textarea" label={gettext("메모")} />
        <:actions>
          <.button type="submit" phx-disable-with={gettext("저장 중...")} class="btn btn-primary">
            {gettext("거래처 저장")}
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
