defmodule AutoMyInvoiceWeb.Plugs.ApiAuthTest do
  use AutoMyInvoiceWeb.ConnCase

  alias AutoMyInvoice.{Accounts, ApiKeys}
  alias AutoMyInvoiceWeb.Plugs.ApiAuth

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "apiauth#{System.unique_integer([:positive])}@example.com",
        password: "password123456"
      })

    %{user: user}
  end

  describe "Phoenix.Token bearer auth" do
    test "authenticates a valid signed token", %{conn: conn, user: user} do
      token = ApiAuth.sign_token(user.id)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/v1/dashboard")

      assert json_response(conn, 200)
    end
  end

  describe "API key auth (AMI-46)" do
    test "authenticates a valid ami_ API key", %{conn: conn, user: user} do
      {:ok, %{raw_key: raw_key}} = ApiKeys.generate_api_key(user, %{"name" => "k"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("/api/v1/dashboard")

      assert json_response(conn, 200)
    end

    test "rejects a revoked API key", %{conn: conn, user: user} do
      {:ok, %{api_key: key, raw_key: raw_key}} = ApiKeys.generate_api_key(user, %{"name" => "k"})
      {:ok, _} = ApiKeys.revoke_api_key(user, key.id)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("/api/v1/dashboard")

      assert json_response(conn, 401)
    end

    test "rejects an unknown API key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer ami_unknownkey")
        |> get("/api/v1/dashboard")

      assert json_response(conn, 401)
    end
  end

  describe "missing or malformed auth" do
    test "rejects requests with no authorization header", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard")
      assert json_response(conn, 401)
    end
  end
end
