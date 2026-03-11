defmodule AutoMyInvoice.AI.VisionClientTest do
  use ExUnit.Case

  alias AutoMyInvoice.AI.VisionClient

  describe "extract/2" do
    test "returns error when API key is not configured" do
      original = Application.get_env(:auto_my_invoice, :openai_api_key)
      Application.put_env(:auto_my_invoice, :openai_api_key, nil)

      result = VisionClient.extract("/tmp/nonexistent.png", "png")

      Application.put_env(:auto_my_invoice, :openai_api_key, original)

      assert {:error, "OPENAI_API_KEY not configured"} = result
    end

    test "returns error when API key is empty string" do
      original = Application.get_env(:auto_my_invoice, :openai_api_key)
      Application.put_env(:auto_my_invoice, :openai_api_key, "")

      result = VisionClient.extract("/tmp/nonexistent.png", "png")

      Application.put_env(:auto_my_invoice, :openai_api_key, original)

      assert {:error, "OPENAI_API_KEY not configured"} = result
    end
  end
end
