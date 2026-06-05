defmodule AutoMyInvoiceWeb.BillingLiveTest do
  use AutoMyInvoiceWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AutoMyInvoice.Accounts

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "billing_test@example.com",
        password: "password123456"
      })

    token = Accounts.generate_user_session_token(user)

    conn =
      build_conn()
      |> init_test_session(%{user_token: token})

    %{conn: conn, user: user}
  end

  describe "BillingLive" do
    test "renders billing page with current plan", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/billing")

      assert html =~ "결제"
      assert html =~ "현재 플랜"
      assert html =~ "무료"
    end

    test "shows all plan options", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/billing")

      assert html =~ "Starter"
      assert html =~ "Pro"
      assert html =~ "$9"
      assert html =~ "$29"
    end

    test "shows usage progress for free plan", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/billing")

      assert html =~ "이번 달 송장"
      assert html =~ "0 / 3"
    end

    test "upgrade click shows flash message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/billing")

      html =
        view
        |> element("button[phx-click=upgrade][phx-value-plan=starter]")
        |> render_click()

      assert html =~ "Paddle 결제창"
    end
  end

  describe "downgrade flow (AMI-48)" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          email: "pro_billing#{System.unique_integer([:positive])}@example.com",
          password: "password123456"
        })

      {:ok, user} = Accounts.update_profile(user, %{plan: "pro"})
      token = Accounts.generate_user_session_token(user)
      conn = build_conn() |> init_test_session(%{user_token: token})
      %{conn: conn, user: user}
    end

    test "pro user sees a downgrade button for lower plans", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/billing")
      assert html =~ "다운그레이드"
    end

    test "confirm shows the restricted-features warning modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/billing")

      html =
        view
        |> element("button[phx-click=confirm_downgrade][phx-value-plan=starter]")
        |> render_click()

      assert html =~ "접근이 제한됩니다"
      assert html =~ "팀 관리"
      assert html =~ "API 접근"
      assert html =~ "데이터는 삭제되지 않고"
    end

    test "confirming downgrade changes the plan and preserves data", %{conn: conn, user: user} do
      {:ok, %{api_key: _}} = AutoMyInvoice.ApiKeys.generate_api_key(user, %{"name" => "k"})
      {:ok, _team} = AutoMyInvoice.Teams.create_team(user, %{"name" => "Acme"})

      {:ok, view, _html} = live(conn, ~p"/settings/billing")

      view
      |> element("button[phx-click=confirm_downgrade][phx-value-plan=starter]")
      |> render_click()

      html =
        view
        |> element("button[phx-click=downgrade][phx-value-plan=starter]")
        |> render_click()

      assert html =~ "Starter 플랜으로 변경되었습니다"

      updated = Accounts.get_user!(user.id)
      assert updated.plan == "starter"
      # Data preserved.
      assert AutoMyInvoice.Teams.get_team_for_owner(updated) != nil
      assert length(AutoMyInvoice.ApiKeys.list_api_keys(updated)) == 1
    end
  end
end
