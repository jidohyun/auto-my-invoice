defmodule AutoMyInvoiceWeb.InvoiceLive.NewAddItemTest do
  use AutoMyInvoiceWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AutoMyInvoice.{Accounts, Clients}

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "additem-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "거래처",
        email: "c-#{System.unique_integer([:positive])}@example.com",
        timezone: "Asia/Seoul"
      })

    token = Accounts.generate_user_session_token(user)

    conn =
      build_conn()
      |> init_test_session(%{user_token: token})

    %{conn: conn, user: user, client: client}
  end

  test "clicking 품목 추가 twice yields two line-item rows", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/invoices/new")

    view |> element("button[phx-click=add_item]") |> render_click()
    view |> element("button[phx-click=add_item]") |> render_click()

    html = render(view)
    count = html |> String.split(~s(name="invoice[items][)) |> length() |> Kernel.-(1)
    # Each item produces description/quantity/unit_price -> 3 fields per item.
    # Two items -> 6 occurrences of invoice[items][
    assert count >= 6, "expected 2 item rows (>=6 item fields), got #{count} field occurrences"
  end
end
