defmodule AutoMyInvoice.Repo.Migrations.AddFeedbackToExtractionJobs do
  use Ecto.Migration

  # AMI-38: store the user's corrections to the AI-extracted data so we can
  # measure extraction accuracy and (later) fine-tune prompts. corrected_data
  # holds the edited field map; feedback_submitted_at marks when the user
  # confirmed the correction.
  def change do
    alter table(:extraction_jobs) do
      add :corrected_data, :map
      add :feedback_submitted_at, :utc_datetime
    end
  end
end
