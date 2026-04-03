defmodule AutoMyInvoiceWeb.AnalyticsLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Analytics

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Analytics")
     |> load_analytics(user)}
  end

  defp load_analytics(socket, user) do
    monthly = Analytics.monthly_collections(user.id, 6)
    status_dist = Analytics.status_distribution(user.id)
    aging = Analytics.invoice_aging(user.id)
    forecast = Analytics.cashflow_forecast(user.id, 90)

    socket
    |> assign(:monthly_collections, monthly)
    |> assign(:status_distribution, status_dist)
    |> assign(:invoice_aging, aging)
    |> assign(:cashflow_forecast, forecast)
    |> assign(:monthly_chart_data, build_monthly_chart_data(monthly))
    |> assign(:status_chart_data, build_status_chart_data(status_dist))
    |> assign(:aging_chart_data, build_aging_chart_data(aging))
    |> assign(:forecast_chart_data, build_forecast_chart_data(forecast))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
      <div>
        <h2 class="text-3xl font-semibold font-display">Analytics</h2>
        <p class="text-base-content/60 text-sm mt-1">Collection trends, aging, and cashflow forecast</p>
      </div>
      <.link navigate={~p"/"} class="btn btn-ghost btn-sm gap-1">
        <.icon name="hero-arrow-left" class="size-4" /> Back to Dashboard
      </.link>
    </header>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <%!-- Monthly Collection Trends --%>
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-lg font-semibold mb-4">Monthly Collection Trends</h3>
        <%= if has_chart_data?(@monthly_collections) do %>
          <div
            id="monthly-chart"
            phx-hook="ChartHook"
            phx-update="ignore"
            data-chart-type="bar"
            data-chart-data={Jason.encode!(@monthly_chart_data)}
            data-chart-options={Jason.encode!(monthly_chart_options())}
            class="h-64"
          >
            <canvas></canvas>
          </div>
        <% else %>
          <.empty_chart_state message="No invoice data yet. Create invoices to see collection trends." />
        <% end %>
      </div>

      <%!-- Invoice Status Distribution --%>
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-lg font-semibold mb-4">Invoice Status Distribution</h3>
        <%= if has_chart_data?(@status_distribution) do %>
          <div
            id="status-chart"
            phx-hook="ChartHook"
            phx-update="ignore"
            data-chart-type="doughnut"
            data-chart-data={Jason.encode!(@status_chart_data)}
            data-chart-options={Jason.encode!(%{plugins: %{legend: %{position: "bottom"}}})}
            class="h-64"
          >
            <canvas></canvas>
          </div>
        <% else %>
          <.empty_chart_state message="No invoices yet. Create invoices to see status distribution." />
        <% end %>
      </div>

      <%!-- Invoice Aging --%>
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-lg font-semibold mb-4">Invoice Aging</h3>
        <%= if has_aging_data?(@invoice_aging) do %>
          <div
            id="aging-chart"
            phx-hook="ChartHook"
            phx-update="ignore"
            data-chart-type="bar"
            data-chart-data={Jason.encode!(@aging_chart_data)}
            data-chart-options={Jason.encode!(aging_chart_options())}
            class="h-64"
          >
            <canvas></canvas>
          </div>
        <% else %>
          <.empty_chart_state message="No outstanding invoices. All caught up!" />
        <% end %>
      </div>

      <%!-- Cashflow Forecast --%>
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-lg font-semibold mb-4">Cashflow Forecast (90 days)</h3>
        <%= if has_chart_data?(@cashflow_forecast) do %>
          <div
            id="forecast-chart"
            phx-hook="ChartHook"
            phx-update="ignore"
            data-chart-type="line"
            data-chart-data={Jason.encode!(@forecast_chart_data)}
            data-chart-options={Jason.encode!(forecast_chart_options())}
            class="h-64"
          >
            <canvas></canvas>
          </div>
        <% else %>
          <.empty_chart_state message="No unpaid invoices to forecast. Great job!" />
        <% end %>
      </div>
    </div>
    """
  end

  defp empty_chart_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center h-64 text-base-content/40">
      <span class="material-icons text-4xl mb-2">bar_chart</span>
      <p class="text-sm text-center">{@message}</p>
    </div>
    """
  end

  ## Chart data builders

  defp build_monthly_chart_data(monthly) do
    %{
      labels: Enum.map(monthly, & &1.month),
      datasets: [
        %{
          label: "Invoiced",
          data: Enum.map(monthly, &Decimal.to_float(&1.invoiced)),
          backgroundColor: "rgba(99, 102, 241, 0.5)",
          borderColor: "rgb(99, 102, 241)",
          borderWidth: 1
        },
        %{
          label: "Collected",
          data: Enum.map(monthly, &Decimal.to_float(&1.collected)),
          backgroundColor: "rgba(34, 197, 94, 0.5)",
          borderColor: "rgb(34, 197, 94)",
          borderWidth: 1
        }
      ]
    }
  end

  defp build_status_chart_data(status_dist) do
    colors = %{
      "draft" => "rgba(156, 163, 175, 0.7)",
      "sent" => "rgba(59, 130, 246, 0.7)",
      "overdue" => "rgba(239, 68, 68, 0.7)",
      "partially_paid" => "rgba(245, 158, 11, 0.7)",
      "paid" => "rgba(34, 197, 94, 0.7)",
      "cancelled" => "rgba(107, 114, 128, 0.7)"
    }

    %{
      labels: Enum.map(status_dist, &format_status(&1.status)),
      datasets: [
        %{
          data: Enum.map(status_dist, & &1.count),
          backgroundColor: Enum.map(status_dist, &Map.get(colors, &1.status, "rgba(156, 163, 175, 0.7)"))
        }
      ]
    }
  end

  defp build_aging_chart_data(aging) do
    buckets = ["0-30", "31-60", "61-90", "90+"]
    colors = [
      "rgba(34, 197, 94, 0.7)",
      "rgba(245, 158, 11, 0.7)",
      "rgba(249, 115, 22, 0.7)",
      "rgba(239, 68, 68, 0.7)"
    ]

    %{
      labels: Enum.map(buckets, &"#{&1} days"),
      datasets: [
        %{
          label: "Outstanding Amount",
          data: Enum.map(buckets, fn bucket ->
            aging |> Map.get(bucket, %{total: Decimal.new(0)}) |> Map.get(:total) |> Decimal.to_float()
          end),
          backgroundColor: colors,
          borderWidth: 1
        }
      ]
    }
  end

  defp build_forecast_chart_data(forecast) do
    %{
      labels: Enum.map(forecast, &Date.to_string(&1.date)),
      datasets: [
        %{
          label: "Expected Payment",
          data: Enum.map(forecast, &Decimal.to_float(&1.expected_amount)),
          fill: true,
          backgroundColor: "rgba(99, 102, 241, 0.1)",
          borderColor: "rgb(99, 102, 241)",
          borderWidth: 2,
          tension: 0.3,
          pointRadius: 4
        }
      ]
    }
  end

  ## Chart options

  defp monthly_chart_options do
    %{
      scales: %{
        y: %{beginAtZero: true, ticks: %{callback_prefix: "$"}},
        x: %{grid: %{display: false}}
      },
      plugins: %{legend: %{position: "top"}}
    }
  end

  defp aging_chart_options do
    %{
      indexAxis: "y",
      scales: %{
        x: %{beginAtZero: true}
      },
      plugins: %{legend: %{display: false}}
    }
  end

  defp forecast_chart_options do
    %{
      scales: %{
        y: %{beginAtZero: true},
        x: %{grid: %{display: false}}
      },
      plugins: %{legend: %{position: "top"}}
    }
  end

  ## Helpers

  defp has_chart_data?(data) when is_list(data), do: data != []
  defp has_chart_data?(_), do: false

  defp has_aging_data?(aging) when is_map(aging) do
    aging
    |> Map.values()
    |> Enum.any?(fn %{count: count} -> count > 0 end)
  end

  defp has_aging_data?(_), do: false

  defp format_status(status) do
    status |> String.replace("_", " ") |> String.capitalize()
  end
end
