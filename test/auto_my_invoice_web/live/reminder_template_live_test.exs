defmodule AutoMyInvoiceWeb.ReminderTemplateLiveTest do
  use AutoMyInvoiceWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.Reminders

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "tmpl-live-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    token = Accounts.generate_user_session_token(user)

    conn =
      build_conn()
      |> init_test_session(%{user_token: token})

    %{conn: conn, user: user}
  end

  describe "ReminderTemplateLive" do
    test "renders the template editor with step tabs and variable hints", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/reminders")

      assert html =~ "리마인더 템플릿"
      assert html =~ "1단계"
      assert html =~ "{{client_name}}"
      assert html =~ "{{amount}}"
      assert html =~ "{{due_date}}"
    end

    test "live preview interpolates sample data on validate", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/reminders")

      html =
        view
        |> form("#template_form", %{
          "template" => %{
            "tone" => "friendly",
            "subject_template" => "{{amount}} 결제",
            "body_template" => "{{client_name}}님께 {{due_date}}"
          }
        })
        |> render_change()

      # Sample data injected by the LiveView
      assert html =~ "₩1,200,000 결제"
      assert html =~ "홍길동님께"
      assert html =~ "2026년 05월 20일"
    end

    test "saves a template and shows flash", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings/reminders")

      html =
        view
        |> form("#template_form", %{
          "template" => %{
            "tone" => "firm",
            "subject_template" => "최종 안내 {{amount}}",
            "body_template" => "{{client_name}}님, 결제 부탁드립니다."
          }
        })
        |> render_submit()

      assert html =~ "저장되었습니다"

      template = Reminders.get_template(user.id, 1)
      assert template.subject_template == "최종 안내 {{amount}}"
      assert template.body_template == "{{client_name}}님, 결제 부탁드립니다."
      assert template.tone == "firm"
    end

    test "switching steps loads that step's existing template", %{conn: conn, user: user} do
      {:ok, _t} =
        Reminders.create_template(user.id, %{
          step: 2,
          tone: "gentle",
          subject_template: "2단계 제목",
          body_template: "2단계 본문"
        })

      {:ok, view, _html} = live(conn, ~p"/settings/reminders")

      html =
        view
        |> element("button[phx-value-step=\"2\"]")
        |> render_click()

      assert html =~ "2단계 제목"
      assert html =~ "2단계 본문"
    end
  end
end
