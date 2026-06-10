defmodule AutoMyInvoice.AnalyticsTest do
  use AutoMyInvoice.DataCase

  alias AutoMyInvoice.Analytics
  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.Clients
  alias AutoMyInvoice.Invoices

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "analytics-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  defp create_client(user, attrs \\ %{}) do
    {:ok, client} =
      Clients.create_client(
        user.id,
        Map.merge(
          %{
            name: "Client #{System.unique_integer([:positive])}",
            email: "client-#{System.unique_integer([:positive])}@example.com"
          },
          attrs
        )
      )

    client
  end

  defp create_invoice(user, client, attrs) do
    {:ok, invoice} =
      Invoices.create_invoice(
        user,
        Map.merge(
          %{
            amount: Decimal.new("1000.00"),
            # KRW by default so aging/cashflow/status tests exercise amount
            # aggregation without depending on a cached FX rate. Multi-currency
            # behavior is covered explicitly in the currency_breakdown describe.
            currency: "KRW",
            due_date: Date.add(Date.utc_today(), 30),
            client_id: client.id
          },
          attrs
        )
      )

    invoice
  end

  describe "monthly_collections/2" do
    test "returns empty months when no invoices exist" do
      user = create_user()
      result = Analytics.monthly_collections(user.id, 3)

      assert length(result) == 3

      Enum.each(result, fn row ->
        assert row.invoiced == Decimal.new(0)
        assert row.collected == Decimal.new(0)
        assert row.count == 0
      end)
    end

    test "returns correct aggregation for invoiced amounts" do
      user = create_user()
      client = create_client(user)

      _inv1 = create_invoice(user, client, %{amount: Decimal.new("500.00")})
      _inv2 = create_invoice(user, client, %{amount: Decimal.new("300.00")})

      result = Analytics.monthly_collections(user.id, 1)
      current_month = Calendar.strftime(Date.utc_today(), "%Y-%m")

      current = Enum.find(result, fn r -> r.month == current_month end)
      assert current != nil
      assert Decimal.equal?(current.invoiced, Decimal.new("800.00"))
      assert current.count == 2
    end

    test "returns correct aggregation for collected amounts" do
      user = create_user()
      client = create_client(user)

      inv = create_invoice(user, client, %{amount: Decimal.new("1000.00")})
      {:ok, _sent} = Invoices.mark_as_sent(inv)
      sent = Invoices.get_invoice!(user.id, inv.id)
      {:ok, _paid} = Invoices.mark_as_paid(sent)

      result = Analytics.monthly_collections(user.id, 1)
      current_month = Calendar.strftime(Date.utc_today(), "%Y-%m")

      current = Enum.find(result, fn r -> r.month == current_month end)
      assert current != nil
      assert Decimal.equal?(current.collected, Decimal.new("1000.00"))
    end

    test "respects months parameter" do
      user = create_user()
      assert length(Analytics.monthly_collections(user.id, 3)) == 3
      assert length(Analytics.monthly_collections(user.id, 12)) == 12
    end
  end

  describe "status_distribution/1" do
    test "returns empty list when no invoices" do
      user = create_user()
      assert Analytics.status_distribution(user.id) == []
    end

    test "returns count and total per status" do
      user = create_user()
      client = create_client(user)

      _draft1 = create_invoice(user, client, %{amount: Decimal.new("100.00")})
      _draft2 = create_invoice(user, client, %{amount: Decimal.new("200.00")})

      inv3 = create_invoice(user, client, %{amount: Decimal.new("500.00")})
      {:ok, _sent} = Invoices.mark_as_sent(inv3)

      result = Analytics.status_distribution(user.id)

      draft_row = Enum.find(result, fn r -> r.status == "draft" end)
      assert draft_row != nil
      assert draft_row.count == 2
      assert Decimal.equal?(draft_row.total, Decimal.new("300.00"))

      sent_row = Enum.find(result, fn r -> r.status == "sent" end)
      assert sent_row != nil
      assert sent_row.count == 1
      assert Decimal.equal?(sent_row.total, Decimal.new("500.00"))
    end
  end

  describe "invoice_aging/1" do
    test "returns zero buckets when no unpaid invoices" do
      user = create_user()
      result = Analytics.invoice_aging(user.id)

      assert result["0-30"].count == 0
      assert result["31-60"].count == 0
      assert result["61-90"].count == 0
      assert result["90+"].count == 0
    end

    test "buckets unpaid invoices correctly by days since due_date" do
      user = create_user()
      client = create_client(user)

      # Invoice due 10 days ago -> 0-30 bucket
      inv1 =
        create_invoice(user, client, %{
          amount: Decimal.new("100.00"),
          due_date: Date.add(Date.utc_today(), 10)
        })

      {:ok, _} = Invoices.mark_as_sent(inv1)

      # Invoice due 45 days ago -> 31-60 bucket
      inv2 =
        create_invoice(user, client, %{
          amount: Decimal.new("200.00"),
          due_date: Date.add(Date.utc_today(), 10)
        })

      {:ok, _} = Invoices.mark_as_sent(inv2)
      # Update due_date directly so it appears overdue by 45 days
      Repo.update_all(
        from(i in AutoMyInvoice.Invoices.Invoice, where: i.id == ^inv2.id),
        set: [due_date: Date.add(Date.utc_today(), -45), status: "overdue"]
      )

      result = Analytics.invoice_aging(user.id)

      # inv1 is due in 10 days, so days_overdue = -10, bucket "0-30"
      assert result["0-30"].count == 1

      # inv2 is overdue by 45 days, bucket "31-60"
      assert result["31-60"].count == 1
      assert Decimal.equal?(result["31-60"].total, Decimal.new("200.00"))
    end
  end

  describe "cashflow_forecast/2" do
    test "returns empty list when no unpaid invoices" do
      user = create_user()
      assert Analytics.cashflow_forecast(user.id) == []
    end

    test "uses client avg_payment_days to predict payment date" do
      user = create_user()
      client = create_client(user)

      # Set avg_payment_days on client
      Clients.update_client(client, %{})

      Repo.update_all(
        from(c in AutoMyInvoice.Clients.Client, where: c.id == ^client.id),
        set: [avg_payment_days: 5]
      )

      due_date = Date.add(Date.utc_today(), 10)

      inv =
        create_invoice(user, client, %{
          amount: Decimal.new("500.00"),
          due_date: due_date
        })

      {:ok, _} = Invoices.mark_as_sent(inv)

      result = Analytics.cashflow_forecast(user.id, 90)

      assert length(result) == 1
      forecast = hd(result)
      # predicted_date = due_date + 5 days
      assert forecast.date == Date.add(due_date, 5)
      assert Decimal.equal?(forecast.expected_amount, Decimal.new("500.00"))
      assert forecast.invoice_count == 1
    end

    test "groups invoices by predicted date" do
      user = create_user()
      client = create_client(user)

      due_date = Date.add(Date.utc_today(), 15)
      inv1 = create_invoice(user, client, %{amount: Decimal.new("300.00"), due_date: due_date})
      inv2 = create_invoice(user, client, %{amount: Decimal.new("200.00"), due_date: due_date})
      {:ok, _} = Invoices.mark_as_sent(inv1)
      {:ok, _} = Invoices.mark_as_sent(inv2)

      result = Analytics.cashflow_forecast(user.id, 90)

      assert length(result) == 1
      forecast = hd(result)
      assert Decimal.equal?(forecast.expected_amount, Decimal.new("500.00"))
      assert forecast.invoice_count == 2
    end

    test "excludes forecasts beyond the horizon" do
      user = create_user()
      client = create_client(user)

      # Invoice due 100 days from now, no avg_payment_days offset
      inv =
        create_invoice(user, client, %{
          amount: Decimal.new("1000.00"),
          due_date: Date.add(Date.utc_today(), 100)
        })

      {:ok, _} = Invoices.mark_as_sent(inv)

      # With 90 day horizon, should be excluded
      result = Analytics.cashflow_forecast(user.id, 90)
      assert result == []

      # With 120 day horizon, should be included
      result = Analytics.cashflow_forecast(user.id, 120)
      assert length(result) == 1
    end

    test "includes both raw expected_amount and probability weighted_amount" do
      user = create_user()
      client = create_client(user)

      due_date = Date.add(Date.utc_today(), 15)
      inv = create_invoice(user, client, %{amount: Decimal.new("1000.00"), due_date: due_date})
      {:ok, _} = Invoices.mark_as_sent(inv)

      result = Analytics.cashflow_forecast(user.id, 90)
      forecast = hd(result)

      # raw expected amount unchanged (full remaining)
      assert Decimal.equal?(forecast.expected_amount, Decimal.new("1000.00"))
      # weighted_amount present and not greater than expected
      assert Map.has_key?(forecast, :weighted_amount)
      assert Decimal.compare(forecast.weighted_amount, forecast.expected_amount) != :gt
    end
  end

  describe "cashflow_forecast/2 collection-rate weighting (AMI-33)" do
    # AMI-33: weight predicted inflow by each client's historical on_time_rate
    defp create_invoice!(user, client, attrs) do
      defaults = %{
        amount: Decimal.new("1000"),
        currency: "KRW",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        status: "draft",
        paid_amount: Decimal.new("0")
      }

      merged = Map.merge(defaults, attrs)

      %AutoMyInvoice.Invoices.Invoice{user_id: user.id}
      |> Ecto.Changeset.change(
        invoice_number: "INV-AN-#{System.unique_integer([:positive])}",
        amount: merged.amount,
        amount_krw: Map.get(merged, :amount_krw),
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

    test "weighted_amount scales by client on_time_rate" do
      user = create_user()
      client = create_client(user)

      # Build a 50% on_time_rate history: 1 on time, 1 late.
      create_invoice!(user, client, %{
        status: "paid",
        paid_amount: Decimal.new("1000"),
        due_date: ~D[2026-01-10],
        sent_at: ~U[2026-01-01 10:00:00Z],
        paid_at: ~U[2026-01-11 10:00:00Z]
      })

      create_invoice!(user, client, %{
        status: "paid",
        paid_amount: Decimal.new("1000"),
        due_date: ~D[2026-02-10],
        sent_at: ~U[2026-02-01 10:00:00Z],
        paid_at: ~U[2026-02-25 10:00:00Z]
      })

      assert Clients.on_time_rate(client.id) == 50.0

      due_date = Date.add(Date.utc_today(), 10)
      open_inv = create_invoice!(user, client, %{amount: Decimal.new("800"), due_date: due_date})

      Repo.update_all(
        from(i in AutoMyInvoice.Invoices.Invoice, where: i.id == ^open_inv.id),
        set: [status: "sent"]
      )

      result = Analytics.cashflow_forecast(user.id, 120)
      forecast = hd(result)

      assert Decimal.equal?(forecast.expected_amount, Decimal.new("800"))
      # weighted by 50% on-time rate => 400
      assert Decimal.equal?(forecast.weighted_amount, Decimal.new("400.0"))
    end

    test "uses default collection probability when client has no history" do
      user = create_user()
      client = create_client(user)

      due_date = Date.add(Date.utc_today(), 10)
      inv = create_invoice(user, client, %{amount: Decimal.new("1000.00"), due_date: due_date})
      {:ok, _} = Invoices.mark_as_sent(inv)

      result = Analytics.cashflow_forecast(user.id, 90)
      forecast = hd(result)

      # No history -> weighted between 0 and full expected
      assert Decimal.compare(forecast.weighted_amount, Decimal.new(0)) == :gt
      assert Decimal.compare(forecast.weighted_amount, forecast.expected_amount) != :gt
    end
  end

  describe "currency_breakdown/1" do
    # AMI-51: multi-currency outstanding totals converted to KRW for display.
    test "returns native + KRW totals and the FX rate per currency" do
      # Cache the FX rates the breakdown will use.
      AutoMyInvoice.FxRates.upsert_rate("USD", Decimal.new("1350"))
      AutoMyInvoice.FxRates.upsert_rate("JPY", Decimal.new("9"))

      user = create_user()
      client = create_client(user)

      usd = create_invoice(user, client, %{amount: Decimal.new("100.00"), currency: "USD"})
      jpy = create_invoice(user, client, %{amount: Decimal.new("10000"), currency: "JPY"})
      {:ok, _} = Invoices.mark_as_sent(usd)
      {:ok, _} = Invoices.mark_as_sent(jpy)

      result = Analytics.currency_breakdown(user.id)

      assert result.multi_currency?
      assert length(result.rows) == 2

      usd_row = Enum.find(result.rows, &(&1.currency == "USD"))
      assert usd_row.converted?
      assert Decimal.eq?(usd_row.native_total, Decimal.new("100.00"))
      assert Decimal.eq?(usd_row.krw_total, Decimal.new("135000.00"))
      assert Decimal.eq?(usd_row.rate, Decimal.new("1350"))

      # JPY: 10000 * 9 = 90000 KRW
      jpy_row = Enum.find(result.rows, &(&1.currency == "JPY"))
      assert Decimal.eq?(jpy_row.krw_total, Decimal.new("90000.00"))

      # total_krw sums every converted row (135000 + 90000)
      assert Decimal.eq?(result.total_krw, Decimal.new("225000.00"))
    end

    test "flags currencies with no cached FX rate as not converted" do
      user = create_user()
      client = create_client(user)
      # No USD rate cached -> conversion fails for this currency.
      inv = create_invoice(user, client, %{amount: Decimal.new("50.00"), currency: "USD"})
      {:ok, _} = Invoices.mark_as_sent(inv)

      result = Analytics.currency_breakdown(user.id)
      usd_row = Enum.find(result.rows, &(&1.currency == "USD"))

      refute usd_row.converted?
      assert usd_row.rate == nil
      assert Decimal.eq?(usd_row.krw_total, Decimal.new(0))
    end

    test "single currency portfolio is not flagged multi_currency" do
      AutoMyInvoice.FxRates.upsert_rate("USD", Decimal.new("1350"))
      user = create_user()
      client = create_client(user)
      inv = create_invoice(user, client, %{amount: Decimal.new("100.00"), currency: "USD"})
      {:ok, _} = Invoices.mark_as_sent(inv)

      result = Analytics.currency_breakdown(user.id)
      refute result.multi_currency?
      assert length(result.rows) == 1
    end

    test "returns empty rows when there are no outstanding invoices" do
      user = create_user()
      result = Analytics.currency_breakdown(user.id)

      assert result.rows == []
      assert Decimal.eq?(result.total_krw, Decimal.new(0))
      refute result.multi_currency?
    end
  end
end
