defmodule AutoMyInvoice.Workers.OcrExtractionWorkerTest do
  use AutoMyInvoice.DataCase
  use Oban.Testing, repo: AutoMyInvoice.Repo

  alias AutoMyInvoice.Workers.OcrExtractionWorker
  alias AutoMyInvoice.{Accounts, Extraction}

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "ocr-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  defp create_extraction_job(user, status \\ "pending") do
    # Create a test file
    dir = Path.join(["priv", "static", "uploads"])
    File.mkdir_p!(dir)
    file_path = Path.join(dir, "test-#{System.unique_integer([:positive])}.png")
    File.write!(file_path, "fake image data")

    {:ok, job} =
      Extraction.create_job(user.id, %{
        file_url: "/uploads/#{Path.basename(file_path)}",
        file_type: "png",
        status: status
      })

    job
  end

  describe "perform/1" do
    test "skips already completed job" do
      user = create_user()
      job = create_extraction_job(user, "completed")

      assert {:cancel, _} = perform_job(OcrExtractionWorker, %{extraction_job_id: job.id})
    end

    test "skips already failed job" do
      user = create_user()
      job = create_extraction_job(user, "failed")

      assert {:cancel, _} = perform_job(OcrExtractionWorker, %{extraction_job_id: job.id})
    end

    test "marks job as processing then handles missing API key" do
      user = create_user()
      job = create_extraction_job(user)

      # Without OPENAI_API_KEY, the VisionClient will return an error
      original = Application.get_env(:auto_my_invoice, :openai_api_key)
      Application.put_env(:auto_my_invoice, :openai_api_key, nil)

      result = perform_job(OcrExtractionWorker, %{extraction_job_id: job.id})

      Application.put_env(:auto_my_invoice, :openai_api_key, original)

      assert {:error, "OPENAI_API_KEY not configured"} = result

      updated = Extraction.get_job!(job.id)
      assert updated.status == "failed"
      assert updated.error_message == "OPENAI_API_KEY not configured"
    end
  end
end
