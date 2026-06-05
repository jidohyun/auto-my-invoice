defmodule AutoMyInvoiceWeb.Api.DeviceControllerTest do
  use AutoMyInvoiceWeb.ConnCase

  alias AutoMyInvoice.{Accounts, Notifications}
  alias AutoMyInvoiceWeb.Plugs.ApiAuth

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "devicetest-#{System.unique_integer([:positive])}@example.com",
        password: "password123456"
      })

    token = ApiAuth.sign_token(user.id)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")

    %{user: user, conn: conn}
  end

  describe "GET /api/v1/devices" do
    test "lists the current user's devices", %{conn: conn, user: user} do
      {:ok, _} =
        Notifications.register_device(user.id, %{"token" => "a", "platform" => "android"})

      {:ok, _} = Notifications.register_device(user.id, %{"token" => "b", "platform" => "ios"})

      conn = get(conn, "/api/v1/devices")

      assert %{"data" => devices, "meta" => %{"total" => 2}} = json_response(conn, 200)
      assert length(devices) == 2
    end
  end

  describe "POST /api/v1/devices" do
    test "registers a device from a top-level token/platform body", %{conn: conn} do
      conn = post(conn, "/api/v1/devices", %{"token" => "fcm-token-1", "platform" => "android"})

      assert %{"data" => device} = json_response(conn, 201)
      assert device["token"] == "fcm-token-1"
      assert device["platform"] == "android"
    end

    test "registers a device from a wrapped device param", %{conn: conn} do
      params = %{"device" => %{"token" => "apns-1", "platform" => "ios"}}
      conn = post(conn, "/api/v1/devices", params)

      assert %{"data" => device} = json_response(conn, 201)
      assert device["platform"] == "ios"
    end

    test "upserts on duplicate token", %{conn: conn, user: user} do
      {:ok, _} =
        Notifications.register_device(user.id, %{"token" => "dup", "platform" => "android"})

      conn = post(conn, "/api/v1/devices", %{"token" => "dup", "platform" => "ios"})

      assert %{"data" => device} = json_response(conn, 201)
      assert device["platform"] == "ios"
      assert length(Notifications.list_user_devices(user.id)) == 1
    end

    test "returns 422 for invalid platform", %{conn: conn} do
      conn = post(conn, "/api/v1/devices", %{"token" => "x", "platform" => "blackberry"})

      assert %{"error" => %{"code" => "validation_error"}} = json_response(conn, 422)
    end
  end

  describe "DELETE /api/v1/devices/:token" do
    test "unregisters a device", %{conn: conn, user: user} do
      {:ok, _} =
        Notifications.register_device(user.id, %{"token" => "rm-me", "platform" => "ios"})

      conn = delete(conn, "/api/v1/devices/rm-me")

      assert response(conn, 204)
      assert Notifications.list_user_devices(user.id) == []
    end

    test "returns 404 for unknown token", %{conn: conn} do
      conn = delete(conn, "/api/v1/devices/does-not-exist")

      assert %{"error" => %{"code" => "not_found"}} = json_response(conn, 404)
    end
  end

  describe "authentication" do
    test "rejects requests without a bearer token" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/devices")

      assert %{"error" => %{"code" => "unauthorized"}} = json_response(conn, 401)
    end

    test "rejects POST without a bearer token" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/devices", %{"token" => "x", "platform" => "android"})

      assert json_response(conn, 401)
    end
  end
end
