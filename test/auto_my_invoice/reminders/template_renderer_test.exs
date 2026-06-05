defmodule AutoMyInvoice.Reminders.TemplateRendererTest do
  use ExUnit.Case, async: true

  alias AutoMyInvoice.Reminders.TemplateRenderer

  describe "render/2" do
    test "interpolates known {{variables}}" do
      result =
        TemplateRenderer.render(
          "{{client_name}}님, {{amount}} 결제를 {{due_date}}까지 부탁드립니다.",
          %{client_name: "홍길동", amount: "₩1,000", due_date: "2026-05-20"}
        )

      assert result == "홍길동님, ₩1,000 결제를 2026-05-20까지 부탁드립니다."
    end

    test "tolerates whitespace inside braces" do
      assert TemplateRenderer.render("{{ client_name }}", %{client_name: "Kim"}) == "Kim"
    end

    test "accepts string-keyed vars" do
      assert TemplateRenderer.render("{{amount}}", %{"amount" => "₩5"}) == "₩5"
    end

    test "converts non-string values with to_string" do
      assert TemplateRenderer.render("{{days_overdue}}일", %{days_overdue: 7}) == "7일"
    end

    test "leaves unknown placeholders untouched" do
      assert TemplateRenderer.render("{{unknown}}", %{client_name: "Kim"}) == "{{unknown}}"
    end

    test "returns empty string for nil template" do
      assert TemplateRenderer.render(nil, %{}) == ""
    end
  end
end
