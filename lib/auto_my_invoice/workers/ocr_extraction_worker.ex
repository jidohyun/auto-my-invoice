defmodule AutoMyInvoice.Workers.OcrExtractionWorker do
  @moduledoc """
  Oban Worker that processes uploaded invoice files through OpenAI Vision API.

  Receives an extraction_job_id, reads the file, calls the Vision API,
  and saves the extracted data back to the ExtractionJob record.
  """

  use Oban.Worker, queue: :extraction, max_attempts: 3

  alias AutoMyInvoice.Extraction
  alias AutoMyInvoice.AI.VisionClient

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"extraction_job_id" => job_id}}) do
    job = Extraction.get_job!(job_id)

    case job.status do
      "completed" ->
        {:cancel, "job already completed"}

      "failed" ->
        {:cancel, "job already failed"}

      _ ->
        process_extraction(job)
    end
  end

  defp process_extraction(job) do
    {:ok, job} = Extraction.mark_processing(job)

    file_path = resolve_file_path(job.file_url)

    case VisionClient.extract(file_path, job.file_type) do
      {:ok, %{raw_response: raw, extracted_data: data, confidence: confidence}} ->
        Extraction.save_result(job, raw, data, confidence)
        :ok

      {:error, reason} ->
        Extraction.mark_failed(job, reason)
        {:error, reason}
    end
  end

  defp resolve_file_path("/uploads/" <> _ = url) do
    Path.join(["priv", "static", url])
  end

  defp resolve_file_path(url), do: url
end
