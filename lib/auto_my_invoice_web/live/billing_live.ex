defmodule AutoMyInvoiceWeb.BillingLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Billing

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    usage = Billing.usage_summary(user.id)
    subscription = Billing.get_active_subscription(user.id)

    {:ok,
     socket
     |> assign(:page_title, "Billing")
     |> assign(:usage, usage)
     |> assign(:subscription, subscription)
     |> assign(:plans, Billing.plans())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="Billing & Subscription" />

    <div class="max-w-4xl space-y-6">
      <%!-- Current Plan --%>
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-lg">Current Plan</h2>
          <div class="flex items-center gap-4 mt-2">
            <span class={"badge badge-lg #{plan_badge_class(@usage.plan)}"}>
              {@usage.plan_name}
            </span>
            <%= if @subscription do %>
              <span class="text-sm text-base-content/60">
                Active since {Calendar.strftime(@subscription.inserted_at, "%B %d, %Y")}
              </span>
            <% end %>
          </div>

          <%!-- Usage --%>
          <%= if @usage.invoices_limit != :unlimited do %>
            <div class="mt-4">
              <div class="flex justify-between text-sm mb-1">
                <span>Invoices this month</span>
                <span class="font-medium">{@usage.invoices_used} / {@usage.invoices_limit}</span>
              </div>
              <progress
                class={"progress #{if @usage.usage_percent >= 100, do: "progress-error", else: "progress-primary"} w-full"}
                value={@usage.usage_percent}
                max="100"
              />
              <%= if !@usage.can_create do %>
                <p class="text-sm text-error mt-2">
                  You've reached your monthly limit. Upgrade to create more invoices.
                </p>
              <% end %>
            </div>
          <% else %>
            <p class="text-sm text-success mt-4 flex items-center">
              <span class="material-icons text-sm mr-1">all_inclusive</span>
              Unlimited invoices
            </p>
          <% end %>
        </div>
      </div>

      <%!-- Plans --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div :for={{plan_id, plan} <- @plans} class={"card bg-base-100 shadow #{if @usage.plan == plan_id, do: "ring-2 ring-primary"}"}>
          <div class="card-body">
            <h3 class="card-title">{plan.name}</h3>
            <p class="text-3xl font-bold mt-2">
              ${plan.price}<span class="text-sm font-normal text-base-content/60">/mo</span>
            </p>
            <ul class="mt-4 space-y-2 text-sm">
              <li class="flex items-center gap-2">
                <span class="material-icons text-success text-sm">check</span>
                {format_limit(plan.monthly_invoices)} invoices/month
              </li>
              <li :if={plan_id != "free"} class="flex items-center gap-2">
                <span class="material-icons text-success text-sm">check</span>
                AI reminders
              </li>
              <li :if={plan_id != "free"} class="flex items-center gap-2">
                <span class="material-icons text-success text-sm">check</span>
                Payment integration
              </li>
              <li :if={plan_id == "pro"} class="flex items-center gap-2">
                <span class="material-icons text-success text-sm">check</span>
                Team & API access
              </li>
            </ul>
            <div class="card-actions mt-4">
              <%= cond do %>
                <% @usage.plan == plan_id -> %>
                  <button class="btn btn-outline btn-sm w-full" disabled>Current Plan</button>
                <% plan_id == "free" -> %>
                  <button class="btn btn-ghost btn-sm w-full" disabled>Free</button>
                <% true -> %>
                  <button
                    class="btn btn-primary btn-sm w-full"
                    phx-click="upgrade"
                    phx-value-plan={plan_id}
                  >
                    {if plan.price > (@plans[@usage.plan] || %{price: 0}).price, do: "Upgrade", else: "Change"} to {plan.name}
                  </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%!-- Subscription Details --%>
      <div :if={@subscription} class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-lg">Subscription Details</h2>
          <div class="grid grid-cols-2 gap-4 mt-2 text-sm">
            <div>
              <span class="text-base-content/60">Status</span>
              <p class="font-medium capitalize">{@subscription.status}</p>
            </div>
            <div>
              <span class="text-base-content/60">Plan</span>
              <p class="font-medium capitalize">{@subscription.plan}</p>
            </div>
            <div :if={@subscription.current_period_end}>
              <span class="text-base-content/60">Next billing</span>
              <p class="font-medium">{Calendar.strftime(@subscription.current_period_end, "%B %d, %Y")}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("upgrade", %{"plan" => _plan}, socket) do
    # In production, this would open Paddle Checkout overlay
    # For now, show a flash message
    {:noreply, put_flash(socket, :info, "Paddle Checkout would open here. Configure PADDLE_API_KEY for production.")}
  end

  defp plan_badge_class("free"), do: "badge-ghost"
  defp plan_badge_class("starter"), do: "badge-primary"
  defp plan_badge_class("pro"), do: "badge-secondary"
  defp plan_badge_class(_), do: "badge-ghost"

  defp format_limit(:unlimited), do: "Unlimited"
  defp format_limit(n), do: to_string(n)
end
