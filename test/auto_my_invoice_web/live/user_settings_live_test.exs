defmodule AutoMyInvoiceWeb.UserSettingsLiveTest do
  @moduledoc """
  LiveView tests for the settings page — covers the business settings bundle
  (AMI-25 통화 / AMI-26 결제조건 / AMI-27 비즈니스 정보 / AMI-28 접두사), the
  Pro plan sections (AMI-45 teams / AMI-46 API keys / AMI-47 branding), and the
  i18n language selector / locale persistence (AMI-49).
  """

  use AutoMyInvoiceWeb.ConnCase, async: false

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

    on_exit(fn -> Gettext.put_locale(AutoMyInvoiceWeb.Gettext, "ko") end)

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

  describe "settings page (default locale — AMI-49)" do
    test "renders settings in Korean by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "설정"
      assert html =~ "프로필"
      assert html =~ "언어"
      assert html =~ "표시 언어"
    end

    test "shows the language selector with all three locales", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "한국어"
      assert html =~ "English"
      assert html =~ "日本語"
    end
  end

  describe "locale persistence (AMI-49)" do
    test "changing the language persists the user's locale", %{conn: conn, user: user} do
      assert user.locale == "ko"

      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> element("form[phx-change=change_locale]")
      |> render_change(%{"locale" => "en"})

      updated = Accounts.get_user!(user.id)
      assert updated.locale == "en"
    end

    test "rejects an unsupported locale", %{user: user} do
      assert {:error, changeset} = Accounts.update_locale(user, "zz")
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :locale)
    end
  end

  describe "rendered language follows the user's locale (AMI-49)" do
    test "an English user sees the settings page in English", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_locale(user, "en")

      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Settings"
      assert html =~ "Profile"
      assert html =~ "Language"
    end

    test "a Japanese user sees the dashboard in Japanese", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_locale(user, "ja")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "ダッシュボード"
      refute html =~ "한눈에 보기"
    end

    test "a Korean (default) user still sees the dashboard in Korean", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "한눈에 보기"
      assert html =~ "미수금 총액"
    end
  end
end
