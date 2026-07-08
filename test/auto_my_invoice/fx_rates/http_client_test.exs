defmodule AutoMyInvoice.FxRates.HttpClientTest do
  use ExUnit.Case, async: true

  alias AutoMyInvoice.FxRates.HttpClient

  setup do
    Req.Test.stub(HttpClient, fn conn ->
      send(self(), {:fx_request_path, conn.request_path})

      Req.Test.json(conn, %{
        "result" => "success",
        "base_code" => "KRW",
        "rates" => %{
          "KRW" => 1,
          "USD" => 0.0008,
          "JPY" => 0.1,
          "EUR" => 0.000625,
          "GBP" => 0.0005,
          "THB" => 0.021956
        }
      })
    end)

    :ok
  end

  describe "fetch_rates/2" do
    test "requests the KRW base endpoint and inverts rates to currency→KRW" do
      assert {:ok, rates} = HttpClient.fetch_rates("KRW", ~w(USD JPY EUR GBP))

      assert_received {:fx_request_path, "/v6/latest/KRW"}
      assert Decimal.eq?(rates["USD"], Decimal.new("1250"))
      assert Decimal.eq?(rates["JPY"], Decimal.new("10"))
      assert Decimal.eq?(rates["EUR"], Decimal.new("1600"))
      assert Decimal.eq?(rates["GBP"], Decimal.new("2000"))
    end

    test "returns only the requested targets, never the KRW identity rate" do
      assert {:ok, rates} = HttpClient.fetch_rates("KRW", ~w(USD JPY))

      assert Map.keys(rates) |> Enum.sort() == ~w(JPY USD)
      refute Map.has_key?(rates, "KRW")
      refute Map.has_key?(rates, "THB")
    end

    test "surfaces the provider error-type on API-level errors" do
      Req.Test.stub(HttpClient, fn conn ->
        Req.Test.json(conn, %{"result" => "error", "error-type" => "unsupported-code"})
      end)

      assert {:error, {:api_error, "unsupported-code"}} =
               HttpClient.fetch_rates("KRW", ~w(USD))
    end

    test "surfaces non-200 responses as http_status errors" do
      Req.Test.stub(HttpClient, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"result" => "error", "error-type" => "quota-reached"})
      end)

      assert {:error, {:http_status, 429, _body}} = HttpClient.fetch_rates("KRW", ~w(USD))
    end
  end
end
