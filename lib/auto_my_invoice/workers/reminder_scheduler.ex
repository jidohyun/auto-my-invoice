defmodule AutoMyInvoice.Workers.ReminderScheduler do
  @moduledoc """
  Oban Cron Worker that runs daily to find due reminders and enqueue ReminderWorker jobs.

  Scans for reminders with status "scheduled" whose scheduled_at is <= now,
  and enqueues a ReminderWorker job for each.
  """

  use Oban.Worker, queue: :default, max_attempts: 1

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Reminders.Reminder
  alias AutoMyInvoice.Workers.ReminderWorker

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()

    due_reminders =
      from(r in Reminder,
        where: r.status == "scheduled",
        where: r.scheduled_at <= ^now,
        select: r.id
      )
      |> Repo.all()

    Enum.each(due_reminders, fn reminder_id ->
      %{reminder_id: reminder_id}
      |> ReminderWorker.new()
      |> Oban.insert()
    end)

    :ok
  end
end
