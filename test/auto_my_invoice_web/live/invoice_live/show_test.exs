defmodule AutoMyInvoiceWeb.InvoiceLive.ShowTest do
  use AutoMyInvoiceWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AutoMyInvoice.{Accounts, Clients, Invoices, Repo}
  alias AutoMyInvoice.Reminders
  alias AutoMyInvoice.Reminders.Reminder

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "show-live-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "테스트 거래처",
        email: "client-#{System.unique_integer([:positive])}@example.com",
        company: "Corp",
        timezone: "Asia/Seoul"
      })

    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        amount: Decimal.new("1000.00"),
        currency: "KRW",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        items: [
          %{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("1000.00")}
        ]
      })

    {:ok, sent} = Invoices.mark_as_sent(invoice)

    token = Accounts.generate_user_session_token(user)

    conn =
      build_conn()
      |> init_test_session(%{user_token: token})

    %{conn: conn, user: user, invoice: sent}
  end

  defp insert_reminder(invoice, step, status, attrs \\ %{}) do
    scheduled_at = DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.truncate(:second)

    base = %{step: step, scheduled_at: scheduled_at, status: status}

    %Reminder{invoice_id: invoice.id}
    |> Reminder.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  describe "custom message reminder (AMI-29)" do
    test "shows the send-reminder action for a sent invoice", %{conn: conn, invoice: invoice} do
      {:ok, _view, html} = live(conn, ~p"/invoices/#{invoice.id}")
      assert html =~ "리마인더 보내기"
    end

    test "toggles the custom message form", %{conn: conn, invoice: invoice} do
      {:ok, view, _html} = live(conn, ~p"/invoices/#{invoice.id}")

      html =
        view
        |> element("button", "리마인더 보내기")
        |> render_click()

      assert html =~ "제목 (선택)"
      assert html =~ "메시지 (선택)"
    end

    test "sends a custom message and persists subject/body", %{conn: conn, invoice: invoice} do
      {:ok, view, _html} = live(conn, ~p"/invoices/#{invoice.id}")

      view |> element("button", "리마인더 보내기") |> render_click()

      html =
        view
        |> form("#reminder-form-card form", %{
          "subject" => "직접 작성한 제목",
          "body" => "직접 작성한 본문입니다."
        })
        |> render_submit()

      assert html =~ "발송 예약되었습니다"

      reminder = Repo.get_by!(Reminder, invoice_id: invoice.id, step: 0)
      assert reminder.email_subject == "직접 작성한 제목"
      assert reminder.email_body == "직접 작성한 본문입니다."
    end
  end

  describe "next-scheduled reminders (AMI-30)" do
    test "lists upcoming scheduled reminders with their scheduled time", %{
      conn: conn,
      invoice: invoice
    } do
      insert_reminder(invoice, 1, "scheduled")
      insert_reminder(invoice, 2, "scheduled")

      {:ok, _view, html} = live(conn, ~p"/invoices/#{invoice.id}")

      assert html =~ "예정된 리마인더"
      assert html =~ "발송 예정"
      assert html =~ "1단계 리마인더"
      assert html =~ "2단계 리마인더"
    end

    test "shows open/click counts in the timeline for sent reminders", %{
      conn: conn,
      invoice: invoice
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      insert_reminder(invoice, 1, "sent", %{
        sent_at: now,
        open_count: 3,
        click_count: 1
      })

      {:ok, _view, html} = live(conn, ~p"/invoices/#{invoice.id}")

      assert html =~ "열람 3회"
      assert html =~ "클릭 1회"
    end

    test "does not list sent reminders as upcoming", %{conn: conn, invoice: invoice} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      insert_reminder(invoice, 1, "sent", %{sent_at: now})

      {:ok, _view, html} = live(conn, ~p"/invoices/#{invoice.id}")
      refute html =~ "예정된 리마인더"
    end
  end
end
