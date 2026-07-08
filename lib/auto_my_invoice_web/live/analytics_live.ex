defmodule AutoMyInvoiceWeb.AnalyticsLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Analytics
  alias AutoMyInvoice.Clients
  alias AutoMyInvoice.Reminders

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "분석")
     |> load_analytics(user)}
  end

  defp load_analytics(socket, user) do
    monthly = Analytics.monthly_collections(user.id, 6)
    status_dist = Analytics.status_distribution(user.id)
    aging = Analytics.invoice_aging(user.id)
    forecast = Analytics.cashflow_forecast(user.id, 90)
    conversion = Reminders.conversion_rate(user.id)
    problem_clients = Clients.problem_clients(user.id)
    currency = Analytics.currency_breakdown(user.id)

    socket
    |> assign(:monthly_collections, monthly)
    |> assign(:status_distribution, status_dist)
    |> assign(:invoice_aging, aging)
    |> assign(:cashflow_forecast, forecast)
    |> assign(:conversion, conversion)
    |> assign(:problem_clients, problem_clients)
    |> assign(:currency_breakdown, currency)
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
        <h2 class="text-3xl font-semibold font-display">분석</h2>
        <p class="text-base-content/60 text-sm mt-1">수금 추이, 연체 분포, 캐시플로우 예측</p>
      </div>
      <.link navigate={~p"/"} class="btn btn-ghost btn-sm gap-1">
        <.icon name="hero-arrow-left" class="size-4" /> 대시보드로
      </.link>
    </header>

    <%!-- Problem Clients Warning (AMI-35) --%>
    <%= if @problem_clients != [] do %>
      <div class="bg-warning/10 border border-warning/40 rounded-xl p-6 mb-6">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-exclamation-triangle" class="size-5 text-warning" />
          <h3 class="text-lg font-semibold">주의 거래처</h3>
          <span class="badge badge-warning badge-sm">{length(@problem_clients)}</span>
        </div>
        <p class="text-sm text-base-content/60 mb-4">
          결제가 지연되거나 정시 결제율이 낮은 거래처입니다. 미리 확인하세요.
        </p>
        <ul class="divide-y divide-base-300">
          <li :for={client <- @problem_clients} class="py-3 flex flex-col gap-1">
            <div class="flex items-center justify-between">
              <span class="font-medium">{client.name}</span>
              <span class="text-sm text-base-content/60">정시 결제율 {client.on_time_rate}%</span>
            </div>
            <ul class="text-xs text-warning/90 list-disc list-inside">
              <li :for={reason <- client.reasons}>{reason}</li>
            </ul>
          </li>
        </ul>
      </div>
    <% end %>

    <%!-- AMI-51: multi-currency outstanding totals converted to KRW --%>
    <div
      :if={@currency_breakdown.rows != []}
      class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300 mb-6"
    >
      <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-2 mb-4">
        <h3 class="text-lg font-semibold">통화별 미수금 (KRW 환산)</h3>
        <div class="text-right">
          <p class="text-xs text-base-content/60">KRW 환산 총액</p>
          <p class="text-2xl font-bold">
            <.money amount={@currency_breakdown.total_krw} currency="KRW" />
          </p>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full text-left border-collapse">
          <thead>
            <tr class="bg-base-200 text-base-content/60 text-xs uppercase tracking-wider">
              <th class="px-4 py-2 font-medium">통화</th>
              <th class="px-4 py-2 font-medium text-right">미수금</th>
              <th class="px-4 py-2 font-medium text-right">적용 환율</th>
              <th class="px-4 py-2 font-medium text-right">KRW 환산</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-base-300">
            <tr :for={row <- @currency_breakdown.rows}>
              <td class="px-4 py-2 font-medium font-mono">{row.currency}</td>
              <td class="px-4 py-2 text-right">
                <.money amount={row.native_total} currency={row.currency} />
              </td>
              <td class="px-4 py-2 text-right text-base-content/60 text-sm">
                {format_fx_rate(row)}
              </td>
              <td class="px-4 py-2 text-right font-medium">
                <%= if row.converted? do %>
                  <.money amount={row.krw_total} currency="KRW" />
                <% else %>
                  <span class="text-warning text-sm">환율 없음</span>
                <% end %>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <p :if={@currency_breakdown.multi_currency?} class="text-xs text-base-content/40 mt-3">
        환율은 최신 캐시된 KRW 기준 환율이며, 매일 자동 갱신됩니다.
        <a href="https://www.exchangerate-api.com" target="_blank" rel="noopener" class="link">
          Rates By Exchange Rate API
        </a>
      </p>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <%!-- Monthly Collection Trends --%>
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-lg font-semibold mb-4">월별 수금 추이</h3>
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
          <.empty_chart_state message="아직 송장 데이터가 없습니다. 송장을 생성하면 수금 추이를 볼 수 있습니다." />
        <% end %>
      </div>

      <%!-- Invoice Status Distribution --%>
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-lg font-semibold mb-4">송장 상태 분포</h3>
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
          <.empty_chart_state message="송장이 없습니다. 송장을 생성하면 상태 분포를 볼 수 있습니다." />
        <% end %>
      </div>

      <%!-- Invoice Aging --%>
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-lg font-semibold mb-4">연체 경과일 분포</h3>
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
          <.empty_chart_state message="미수금 송장이 없습니다. 모두 정리되었습니다!" />
        <% end %>
      </div>

      <%!-- Cashflow Forecast --%>
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-lg font-semibold mb-4">캐시플로우 예측 (90일)</h3>
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
          <.empty_chart_state message="예측할 미결제 송장이 없습니다. 좋습니다!" />
        <% end %>
      </div>

      <%!-- Reminder Conversion Rate (AMI-34) --%>
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300 lg:col-span-2">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold">리마인더 전환율</h3>
          <div class="text-right">
            <p class="text-2xl font-semibold">{@conversion.overall_conversion_rate}%</p>
            <p class="text-xs text-base-content/60">
              {@conversion.overall_converted} / {@conversion.overall_reminded} 결제 전환
            </p>
          </div>
        </div>
        <%= if @conversion.by_step != [] do %>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>단계</th>
                  <th class="text-right">리마인더 발송</th>
                  <th class="text-right">결제 전환</th>
                  <th class="text-right">전환율</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={step <- @conversion.by_step}>
                  <td>{step_label(step.step)}</td>
                  <td class="text-right">{step.reminded}</td>
                  <td class="text-right">{step.converted}</td>
                  <td class="text-right font-medium">{step.conversion_rate}%</td>
                </tr>
              </tbody>
            </table>
          </div>
        <% else %>
          <.empty_chart_state message="아직 발송된 리마인더가 없습니다." />
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
          label: "청구",
          data: Enum.map(monthly, &Decimal.to_float(&1.invoiced)),
          backgroundColor: "rgba(99, 102, 241, 0.5)",
          borderColor: "rgb(99, 102, 241)",
          borderWidth: 1
        },
        %{
          label: "수금",
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
          backgroundColor:
            Enum.map(status_dist, &Map.get(colors, &1.status, "rgba(156, 163, 175, 0.7)"))
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
      labels: Enum.map(buckets, &"#{&1}일"),
      datasets: [
        %{
          label: "미수금",
          data:
            Enum.map(buckets, fn bucket ->
              aging
              |> Map.get(bucket, %{total: Decimal.new(0)})
              |> Map.get(:total)
              |> Decimal.to_float()
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
          label: "예상 입금액",
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
        y: %{beginAtZero: true, ticks: %{callback_prefix: "₩"}},
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

  defp step_label(0), do: "수동"
  defp step_label(1), do: "1차"
  defp step_label(2), do: "2차"
  defp step_label(3), do: "3차"
  defp step_label(step), do: "#{step}차"

  # AMI-51: render "1 USD = ₩1,350" style rate label, or a dash for KRW/missing.
  defp format_fx_rate(%{currency: "KRW"}), do: "-"
  defp format_fx_rate(%{rate: nil}), do: "-"

  defp format_fx_rate(%{currency: currency, rate: rate}) do
    "1 #{currency} = #{format_money(rate, "KRW")}"
  end

  defp format_status("paid"), do: "결제완료"
  defp format_status("sent"), do: "발송"
  defp format_status("overdue"), do: "연체"
  defp format_status("partially_paid"), do: "부분결제"
  defp format_status("draft"), do: "임시저장"
  defp format_status("cancelled"), do: "취소"
  defp format_status(status), do: status
end
