defmodule AutoMyInvoice.Notifications.LogDispatcherTest do
  use ExUnit.Case, async: true

  alias AutoMyInvoice.Notifications.{Device, LogDispatcher}

  defp device(attrs \\ %{}) do
    %Device{
      id: Ecto.UUID.generate(),
      token: "tok_#{System.unique_integer([:positive])}",
      platform: "android"
    }
    |> Map.merge(attrs)
  end

  describe "deliver/2" do
    test "returns a synthetic receipt without contacting an external system" do
      payload = %{title: "결제 완료", body: "송장 #1의 결제가 확인되었습니다."}

      assert {:ok, receipt} = LogDispatcher.deliver(device(), payload)
      assert receipt.stub == true
      assert String.starts_with?(receipt.receipt, "LOG-android-")
      assert receipt.platform == "android"
    end

    test "carries through the data map" do
      payload = %{
        title: "송장 연체",
        body: "기한 초과",
        data: %{"type" => "invoice_overdue", "invoice_id" => "abc"}
      }

      assert {:ok, receipt} = LogDispatcher.deliver(device(%{platform: "ios"}), payload)
      assert receipt.data == %{"type" => "invoice_overdue", "invoice_id" => "abc"}
      assert String.starts_with?(receipt.receipt, "LOG-ios-")
    end

    test "implements the PushDispatcher behaviour" do
      behaviours = LogDispatcher.module_info(:attributes)[:behaviour] || []
      assert AutoMyInvoice.Notifications.PushDispatcher in behaviours
    end
  end
end
