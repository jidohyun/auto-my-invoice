defmodule AutoMyInvoiceWeb.Plugs.LocaleTest do
  use AutoMyInvoiceWeb.ConnCase, async: false

  alias AutoMyInvoiceWeb.Plugs.Locale
  alias AutoMyInvoice.Accounts

  setup do
    # Reset to the source locale before each test so we never leak state.
    on_exit(fn -> Gettext.put_locale(AutoMyInvoiceWeb.Gettext, "ko") end)
    :ok
  end

  defp call_locale(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Locale.call([])
  end

  describe "call/2 locale resolution" do
    test "defaults to the source locale (ko) for anonymous users", %{conn: conn} do
      conn = call_locale(conn)

      assert Gettext.get_locale(AutoMyInvoiceWeb.Gettext) == "ko"
      assert get_session(conn, "locale") == "ko"
    end

    test "uses the logged-in user's preference", %{conn: conn} do
      {:ok, user} =
        Accounts.register_user(%{email: "ja_user@example.com", password: "password123456"})

      {:ok, user} = Accounts.update_locale(user, "ja")

      conn =
        conn
        |> Plug.Conn.assign(:current_user, user)
        |> call_locale()

      assert Gettext.get_locale(AutoMyInvoiceWeb.Gettext) == "ja"
      assert get_session(conn, "locale") == "ja"
    end

    test "falls back to the session locale when no user is present", %{conn: conn} do
      conn
      |> Plug.Test.init_test_session(%{"locale" => "en"})
      |> Locale.call([])

      assert Gettext.get_locale(AutoMyInvoiceWeb.Gettext) == "en"
    end

    test "ignores unsupported locales and falls back to the default", %{conn: conn} do
      conn
      |> Plug.Test.init_test_session(%{"locale" => "zz"})
      |> Locale.call([])

      assert Gettext.get_locale(AutoMyInvoiceWeb.Gettext) == "ko"
    end
  end

  describe "gettext rendering by locale" do
    test "ko renders the Korean source string unchanged" do
      Gettext.put_locale(AutoMyInvoiceWeb.Gettext, "ko")
      assert Gettext.gettext(AutoMyInvoiceWeb.Gettext, "대시보드") == "대시보드"
    end

    test "en renders the English translation" do
      Gettext.put_locale(AutoMyInvoiceWeb.Gettext, "en")
      assert Gettext.gettext(AutoMyInvoiceWeb.Gettext, "대시보드") == "Dashboard"
    end

    test "ja renders the Japanese translation" do
      Gettext.put_locale(AutoMyInvoiceWeb.Gettext, "ja")
      assert Gettext.gettext(AutoMyInvoiceWeb.Gettext, "대시보드") == "ダッシュボード"
    end
  end
end
