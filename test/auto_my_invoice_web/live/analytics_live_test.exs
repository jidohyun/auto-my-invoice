defmodule AutoMyInvoiceWeb.AnalyticsLiveTest do
  @moduledoc """
  LiveView tests for the analytics page. Covers AMI-34 (reminder conversion),
  AMI-35 (problem clients), and AMI-51 (multi-currency outstanding breakdown
  converted to KRW with the FX rate used).
  """

  use AutoMyInvoiceWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AutoMyInvoice.{Accounts, Clients, Invoices, FxRates}
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Invoices.Invoice
  alias AutoMyInvoice.Reminders.Reminder

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "analytics-live-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    token = Accounts.generate_user_session_token(user)

    conn =
      build_conn()
      |> init_test_session(%{user_token: token})

    %{conn: conn, user: user}
  end

  defp create_client(user) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "Client #{System.unique_integer([:positive])}",
        email: "c-#{System.unique_integer([:positive])}@example.com"
      })

    client
  end

  defp create_invoice!(user, client, attrs) do
    defaults = %{
      amount: Decimal.new("1000"),
      currency: "USD",
      due_date: Date.add(Date.utc_today(), 30),
      client_id: client.id,
      status: "draft",
      paid_amount: Decimal.new("0")
    }

    merged = Map.merge(defaults, attrs)

    %Invoice{user_id: user.id}
    |> Ecto.Changeset.change(
      invoice_number: "INV-LIVE-#{System.unique_integer([:positive])}",
      amount: merged.amount,
      currency: merged.currency,
      due_date: merged.due_date,
      status: merged.status,
      client_id: merged.client_id,
      sent_at: Map.get(merged, :sent_at),
      paid_at: Map.get(merged, :paid_at),
      paid_amount: merged.paid_amount
    )
    |> Repo.insert!()
  end

  defp create_outstanding_invoice(user, client, amount, currency) do
    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        amount: Decimal.new(amount),
        currency: currency,
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id
      })

    {:ok, sent} = Invoices.mark_as_sent(invoice)
    sent
  end

  describe "AnalyticsLive base render" do
    test "renders existing analytics sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/analytics")

      assert html =~ "분석"
      assert html =~ "월별 수금 추이"
      assert html =~ "캐시플로우 예측"
    end
  end

  describe "conversion rate section (AMI-34)" do
    test "renders reminder conversion section", %{conn: conn, user: user} do
      {:ok, client} =
        Clients.create_client(user.id, %{name: "Conv", email: "conv@example.com"})

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      sent_at = DateTime.add(now, -3 * 86_400, :second)

      inv =
        create_invoice!(user, client, %{
          status: "paid",
          paid_amount: Decimal.new("1000"),
          paid_at: now,
          sent_at: sent_at
        })

      %Reminder{invoice_id: inv.id}
      |> Reminder.changeset(%{step: 1, scheduled_at: sent_at, status: "sent"})
      |> Ecto.Changeset.put_change(:sent_at, sent_at)
      |> Repo.insert!()

      {:ok, _view, html} = live(conn, ~p"/analytics")

      assert html =~ "리마인더 전환율"
    end
  end

  describe "problem clients section (AMI-35)" do
    test "renders problem client warning when a client is flagged", %{conn: conn, user: user} do
      {:ok, bad} =
        Clients.create_client(user.id, %{name: "Risky Co", email: "risky@example.com"})

      for _ <- 1..2 do
        create_invoice!(user, bad, %{
          amount: Decimal.new("1000"),
          status: "paid",
          paid_amount: Decimal.new("1000"),
          due_date: ~D[2026-01-10],
          sent_at: ~U[2026-01-01 10:00:00Z],
          paid_at: ~U[2026-02-10 10:00:00Z]
        })
      end

      {:ok, _view, html} = live(conn, ~p"/analytics")

      assert html =~ "주의 거래처"
      assert html =~ "Risky Co"
    end

    test "does not render problem section when there are no problem clients", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/analytics")

      refute html =~ "주의 거래처"
    end
  end

  describe "AMI-51 multi-currency KRW breakdown" do
    test "renders per-currency totals, KRW conversion and the FX rate used",
         %{conn: conn, user: user} do
      FxRates.upsert_rate("USD", Decimal.new("1350"))
      FxRates.upsert_rate("JPY", Decimal.new("9"))

      client = create_client(user)
      create_outstanding_invoice(user, client, "100.00", "USD")
      create_outstanding_invoice(user, client, "10000", "JPY")

      {:ok, _view, html} = live(conn, ~p"/analytics")

      assert html =~ "통화별 미수금"
      # native currency rows present
      assert html =~ "USD"
      assert html =~ "JPY"
      # FX rate label "1 USD = ₩1,350"
      assert html =~ "1 USD = ₩1,350"
      # KRW-converted total: 135,000 (USD) + 90,000 (JPY) = 225,000
      assert html =~ "225,000"
    end

    test "shows '환율 없음' when an FX rate is missing", %{conn: conn, user: user} do
      # No USD rate cached.
      client = create_client(user)
      create_outstanding_invoice(user, client, "100.00", "USD")

      {:ok, _view, html} = live(conn, ~p"/analytics")

      assert html =~ "환율 없음"
    end

    test "hides the breakdown panel when there are no outstanding invoices",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/analytics")

      refute html =~ "통화별 미수금"
    end
  end
end
