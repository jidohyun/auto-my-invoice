defmodule AutoMyInvoiceWeb.UserSettingsLiveTest do
  @moduledoc """
  LiveView tests for the settings page — covers the business settings bundle
  (AMI-25 통화 / AMI-26 결제조건 / AMI-27 비즈니스 정보 / AMI-28 접두사).
  """

  use AutoMyInvoiceWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AutoMyInvoice.Accounts

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "settings-live-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    token = Accounts.generate_user_session_token(user)

    conn =
      build_conn()
      |> init_test_session(%{user_token: token})

    %{conn: conn, user: user}
  end

  describe "GET /settings" do
    test "renders business settings fields", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "기본 통화"
      assert html =~ "기본 결제 조건"
      assert html =~ "송장 번호 접두사"
      assert html =~ "사업장 주소"
      assert html =~ "사업자등록번호"
      assert html =~ "로고 이미지 URL"
    end

    test "shows the user's current default currency selected", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_profile(user, %{default_currency: "USD"})

      {:ok, _view, html} = live(conn, ~p"/settings")
      assert html =~ ~s(value="USD" selected)
    end
  end

  describe "save business settings" do
    test "persists currency, payment terms, prefix and business info", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> form("#settings_form",
        profile: %{
          default_currency: "USD",
          payment_terms: 45,
          invoice_prefix: "MYCO",
          business_address: "서울특별시 강남구",
          business_registration_number: "123-45-67890",
          logo_url: "https://example.com/logo.png"
        }
      )
      |> render_submit()

      updated = Accounts.get_user!(user.id)
      assert updated.default_currency == "USD"
      assert updated.payment_terms == 45
      assert updated.invoice_prefix == "MYCO"
      assert updated.business_address == "서울특별시 강남구"
      assert updated.business_registration_number == "123-45-67890"
      assert updated.logo_url == "https://example.com/logo.png"
    end

    test "shows validation error for invalid prefix", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html =
        view
        |> form("#settings_form", profile: %{invoice_prefix: "way-too-long-prefix-value"})
        |> render_submit()

      assert html =~ "1~10자"
    end
  end
end
