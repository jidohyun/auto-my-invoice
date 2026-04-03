defmodule AutoMyInvoiceWeb.Api.AnalyticsControllerTest do
  use AutoMyInvoiceWeb.ConnCase

  alias AutoMyInvoice.Accounts
  alias AutoMyInvoiceWeb.Plugs.ApiAuth

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "analytics-api-#{System.unique_integer([:positive])}@example.com",
        password: "password123456"
      })

    token = ApiAuth.sign_token(user.id)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")

    %{user: user, conn: conn}
  end

  describe "GET /api/v1/dashboard/analytics" do
    test "returns analytics data with default months", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/analytics")

      assert %{"data" => data} = json_response(conn, 200)
      assert Map.has_key?(data, "monthly_collections")
      assert Map.has_key?(data, "status_distribution")
      assert Map.has_key?(data, "invoice_aging")

      assert is_list(data["monthly_collections"])
      assert length(data["monthly_collections"]) == 6

      assert is_list(data["status_distribution"])

      assert is_map(data["invoice_aging"])
      assert Map.has_key?(data["invoice_aging"], "0-30")
      assert Map.has_key?(data["invoice_aging"], "31-60")
      assert Map.has_key?(data["invoice_aging"], "61-90")
      assert Map.has_key?(data["invoice_aging"], "90+")
    end

    test "accepts months parameter", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/analytics?months=3")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data["monthly_collections"]) == 3
    end

    test "returns 401 without authentication" do
      conn = build_conn()
      conn = get(conn, "/api/v1/dashboard/analytics")

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/v1/dashboard/cashflow" do
    test "returns cashflow forecast data", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/cashflow")

      assert %{"data" => data} = json_response(conn, 200)
      assert Map.has_key?(data, "forecast")
      assert is_list(data["forecast"])
    end

    test "accepts days parameter", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/cashflow?days=30")

      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data["forecast"])
    end

    test "returns 401 without authentication" do
      conn = build_conn()
      conn = get(conn, "/api/v1/dashboard/cashflow")

      assert json_response(conn, 401)
    end
  end
end
