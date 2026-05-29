defmodule AutoMyInvoiceWeb.UserSettingsLiveTest do
  @moduledoc """
  LiveView tests for the settings page — covers the business settings bundle
  (AMI-25 통화 / AMI-26 결제조건 / AMI-27 비즈니스 정보 / AMI-28 접두사) and the
  Pro plan sections (AMI-45 teams / AMI-46 API keys / AMI-47 branding).
  """

  use AutoMyInvoiceWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.ApiKeys

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

  defp register_and_log_in(plan) do
    {:ok, user} =
      Accounts.register_user(%{
        email: "settings#{System.unique_integer([:positive])}@example.com",
        password: "password123456"
      })

    user =
      if plan != "free" do
        {:ok, user} = Accounts.update_profile(user, %{plan: plan})
        user
      else
        user
      end

    token = Accounts.generate_user_session_token(user)
    conn = build_conn() |> init_test_session(%{user_token: token})
    %{conn: conn, user: user}
  end

  describe "GET /settings (business settings — AMI-25/26/27/28)" do
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

  describe "free plan user" do
    test "sees Pro sections gated with upgrade copy", %{} do
      %{conn: conn} = register_and_log_in("free")
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "팀 관리"
      assert html =~ "API 키"
      assert html =~ "맞춤 브랜딩"
      assert html =~ "Pro 플랜에서 팀원을 초대"
      refute html =~ "팀 생성"
    end
  end

  describe "pro plan branding (AMI-47)" do
    test "saves brand color", %{} do
      %{conn: conn} = register_and_log_in("pro")
      {:ok, view, _html} = live(conn, ~p"/settings")

      html =
        view
        |> form("#branding_form", brand: %{brand_color: "#112233"})
        |> render_submit()

      assert html =~ "브랜딩이 저장되었습니다"
    end
  end

  describe "pro plan teams (AMI-45)" do
    test "creates a team, invites a member, and sends email", %{} do
      %{conn: conn} = register_and_log_in("pro")
      {:ok, view, html} = live(conn, ~p"/settings")

      assert html =~ "팀 생성"

      view
      |> form("#create_team_form", team: %{name: "Acme"})
      |> render_submit()

      html = render(view)
      assert html =~ "Acme"
      assert html =~ "멤버 초대"

      view
      |> form("#invite_form", member: %{email: "newmember@example.com"})
      |> render_submit()

      assert render(view) =~ "newmember@example.com"
      assert_email_sent(fn email -> assert email.subject =~ "팀" end)
    end

    test "removing a member updates the list", %{} do
      %{conn: conn, user: user} = register_and_log_in("pro")
      {:ok, team} = AutoMyInvoice.Teams.create_team(user, %{"name" => "Acme"})

      {:ok, membership} =
        AutoMyInvoice.Teams.invite_member(team, %{"email" => "gone@example.com"})

      {:ok, view, _html} = live(conn, ~p"/settings")
      assert render(view) =~ "gone@example.com"

      view
      |> element(~s|button[phx-click=remove_member][phx-value-id="#{membership.id}"]|)
      |> render_click()

      refute render(view) =~ "gone@example.com"
    end
  end

  describe "pro plan api keys (AMI-46)" do
    test "creates a key and shows it once", %{} do
      %{conn: conn} = register_and_log_in("pro")
      {:ok, view, _html} = live(conn, ~p"/settings")

      html =
        view
        |> form("#api_key_form", api_key: %{name: "CI token"})
        |> render_submit()

      assert html =~ "API 키가 생성되었습니다"
      assert html =~ "ami_"
      assert html =~ "CI token"
    end

    test "revokes a key", %{} do
      %{conn: conn, user: user} = register_and_log_in("pro")
      {:ok, %{api_key: key}} = ApiKeys.generate_api_key(user, %{"name" => "to revoke"})

      {:ok, view, _html} = live(conn, ~p"/settings")
      assert render(view) =~ "to revoke"

      view
      |> element(~s|button[phx-click=revoke_api_key][phx-value-id="#{key.id}"]|)
      |> render_click()

      refute render(view) =~ "to revoke"
    end
  end
end
