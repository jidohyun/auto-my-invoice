defmodule AutoMyInvoice.RemindersTest do
  use AutoMyInvoice.DataCase

  alias AutoMyInvoice.Reminders
  alias AutoMyInvoice.Reminders.{Reminder, ReminderTemplate}
  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.Clients
  alias AutoMyInvoice.Invoices

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "rem-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  defp create_sent_invoice(user) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "Client",
        email: "client-#{System.unique_integer([:positive])}@example.com",
        company: "Corp",
        timezone: "Asia/Seoul"
      })

    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        amount: Decimal.new("1000.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        items: [
          %{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("1000.00")}
        ]
      })

    {:ok, sent} = Invoices.mark_as_sent(invoice)
    sent = Repo.preload(sent, :client)
    sent
  end

  defp create_reminder(invoice, step, status \\ "scheduled") do
    scheduled_at = DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.truncate(:second)

    {:ok, reminder} =
      %Reminder{invoice_id: invoice.id}
      |> Reminder.changeset(%{step: step, scheduled_at: scheduled_at, status: status})
      |> Repo.insert()

    reminder
  end

  describe "Reminder schema" do
    test "creates reminder with valid attrs" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 1)

      assert reminder.step == 1
      assert reminder.status == "scheduled"
      assert reminder.invoice_id == invoice.id
    end

    test "validates step inclusion" do
      changeset =
        Reminder.changeset(%Reminder{}, %{
          step: 5,
          scheduled_at: DateTime.utc_now()
        })

      assert errors_on(changeset).step != []
    end

    test "validates status inclusion" do
      changeset =
        Reminder.changeset(%Reminder{}, %{
          step: 1,
          scheduled_at: DateTime.utc_now(),
          status: "invalid"
        })

      assert errors_on(changeset).status != []
    end

    test "validates required fields" do
      changeset = Reminder.changeset(%Reminder{}, %{})
      assert errors_on(changeset).step != []
      assert errors_on(changeset).scheduled_at != []
    end
  end

  describe "ReminderTemplate schema" do
    test "creates template with valid attrs" do
      changeset =
        ReminderTemplate.changeset(%ReminderTemplate{}, %{
          step: 1,
          tone: "friendly",
          subject_template: "Invoice <%= @invoice_number %>",
          body_template: "Hello <%= @client_name %>"
        })

      assert changeset.valid?
    end

    test "validates tone inclusion" do
      changeset =
        ReminderTemplate.changeset(%ReminderTemplate{}, %{
          step: 1,
          tone: "angry",
          subject_template: "test",
          body_template: "test"
        })

      assert errors_on(changeset).tone != []
    end
  end

  describe "schedule_reminders/1" do
    # R-1: 3개 리마인더 스케줄링
    test "creates 3 reminders for steps 1, 2, 3" do
      user = create_user()
      invoice = create_sent_invoice(user)

      assert {:ok, reminders} = Reminders.schedule_reminders(invoice)
      assert length(reminders) == 3

      steps = Enum.map(reminders, & &1.step) |> Enum.sort()
      assert steps == [1, 2, 3]

      Enum.each(reminders, fn r ->
        assert r.status == "scheduled"
        assert r.scheduled_at != nil
      end)
    end

    # R-2: 스케줄 시각 계산
    test "schedules step 1 at D+1 in client timezone morning" do
      user = create_user()
      invoice = create_sent_invoice(user)
      {:ok, reminders} = Reminders.schedule_reminders(invoice)

      step1 = Enum.find(reminders, &(&1.step == 1))
      step1 = Repo.get!(Reminder, step1.id)

      # D+1 이후여야 함
      expected_min = Date.add(invoice.due_date, 1)
      scheduled_date = DateTime.to_date(step1.scheduled_at)
      assert Date.compare(scheduled_date, expected_min) in [:eq, :gt]
    end

    # R-3: 주말 건너뛰기
    test "skips weekends in scheduling" do
      # skip_weekends는 private이므로 간접 테스트
      # 토요일 마감일 → step1 D+1 = 일요일 → 월요일로 이동
      user = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{
          name: "Weekend Client",
          email: "wk-#{System.unique_integer([:positive])}@example.com",
          company: "Corp",
          timezone: "UTC"
        })

      # 다가오는 금요일 찾기
      today = Date.utc_today()
      days_until_friday = rem(5 - Date.day_of_week(today) + 7, 7)
      days_until_friday = if days_until_friday == 0, do: 7, else: days_until_friday
      next_friday = Date.add(today, days_until_friday)

      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          amount: Decimal.new("500.00"),
          currency: "USD",
          due_date: next_friday,
          client_id: client.id,
          items: [
            %{description: "Test", quantity: Decimal.new(1), unit_price: Decimal.new("500.00")}
          ]
        })

      {:ok, sent} = Invoices.mark_as_sent(invoice)
      sent = Repo.preload(sent, :client)

      {:ok, reminders} = Reminders.schedule_reminders(sent)

      # step1 D+1 = 토요일 → 월요일(day_of_week 1)
      step1 = Enum.find(reminders, &(&1.step == 1))
      step1 = Repo.get!(Reminder, step1.id)
      day = Date.day_of_week(DateTime.to_date(step1.scheduled_at))
      assert day in 1..5, "Scheduled day should be a weekday, got #{day}"
    end
  end

  describe "cancel_pending_reminders/1" do
    # R-4: 결제 완료 시 리마인더 취소
    test "cancels all pending/scheduled reminders for invoice" do
      user = create_user()
      invoice = create_sent_invoice(user)

      _r1 = create_reminder(invoice, 1, "scheduled")
      _r2 = create_reminder(invoice, 2, "pending")
      # 이미 발송됨 → 취소 안됨
      _r3 = create_reminder(invoice, 3, "sent")

      {cancelled_count, nil} = Reminders.cancel_pending_reminders(invoice.id)
      assert cancelled_count == 2

      reminders = Reminders.list_reminders_for_invoice(invoice.id)
      statuses = Enum.map(reminders, & &1.status)
      assert "cancelled" in statuses
      # 발송된 것은 그대로
      assert "sent" in statuses
    end
  end

  describe "record_open/1" do
    # R-9: 오픈 추적
    test "increments open count and records first opened_at" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 1, "sent")

      {:ok, opened} = Reminders.record_open(reminder.id)
      assert opened.open_count == 1
      assert opened.opened_at != nil

      first_opened_at = opened.opened_at
      {:ok, opened_again} = Reminders.record_open(reminder.id)
      assert opened_again.open_count == 2
      # 최초 시각 유지
      assert opened_again.opened_at == first_opened_at
    end
  end

  describe "record_click/1" do
    # R-10: 클릭 추적
    test "increments click count and records first clicked_at" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 1, "sent")

      {:ok, clicked} = Reminders.record_click(reminder.id)
      assert clicked.click_count == 1
      assert clicked.clicked_at != nil

      first_clicked_at = clicked.clicked_at
      {:ok, clicked_again} = Reminders.record_click(reminder.id)
      assert clicked_again.click_count == 2
      assert clicked_again.clicked_at == first_clicked_at
    end
  end

  describe "send_manual_reminder/1" do
    test "creates and enqueues manual reminder for sent invoice" do
      user = create_user()
      invoice = create_sent_invoice(user)

      assert {:ok, reminder} = Reminders.send_manual_reminder(invoice)
      assert reminder.step == 0
      assert reminder.invoice_id == invoice.id

      # With Oban inline testing, the worker runs immediately
      updated = Repo.get!(Reminder, reminder.id)
      assert updated.status == "sent"
      assert updated.sent_at != nil
    end

    test "creates and enqueues manual reminder for overdue invoice" do
      user = create_user()
      invoice = create_sent_invoice(user)

      {:ok, overdue} = Invoices.mark_as_overdue(invoice)
      overdue = Repo.preload(overdue, :client)

      assert {:ok, reminder} = Reminders.send_manual_reminder(overdue)
      assert reminder.step == 0

      updated = Repo.get!(Reminder, reminder.id)
      assert updated.status == "sent"
    end

    test "rejects for draft invoice" do
      user = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{
          name: "Draft Client",
          email: "draft-#{System.unique_integer([:positive])}@example.com",
          company: "Corp",
          timezone: "UTC"
        })

      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          amount: Decimal.new("1000.00"),
          currency: "USD",
          due_date: Date.add(Date.utc_today(), 30),
          client_id: client.id,
          items: [
            %{
              description: "Service",
              quantity: Decimal.new(1),
              unit_price: Decimal.new("1000.00")
            }
          ]
        })

      invoice = Repo.preload(invoice, :client)

      assert {:error, :invalid_status} = Reminders.send_manual_reminder(invoice)
    end

    test "rejects for paid invoice" do
      user = create_user()
      invoice = create_sent_invoice(user)
      {:ok, paid} = Invoices.mark_as_paid(invoice)
      paid = Repo.preload(paid, :client)

      assert {:error, :invalid_status} = Reminders.send_manual_reminder(paid)
    end

    test "rate limits to once per day per invoice" do
      user = create_user()
      invoice = create_sent_invoice(user)

      # First send succeeds (inline Oban sets sent_at automatically)
      assert {:ok, _reminder} = Reminders.send_manual_reminder(invoice)

      # Second send on same day is rate limited
      assert {:error, :rate_limited} = Reminders.send_manual_reminder(invoice)
    end
  end

  describe "avg_days_to_payment/1" do
    test "calculates average days from reminder to payment by step" do
      user = create_user()
      invoice = create_sent_invoice(user)

      # Mark invoice as paid
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      invoice
      |> Ecto.Changeset.change(status: "paid", paid_at: now, paid_amount: invoice.amount)
      |> Repo.update!()

      # Create a sent reminder with sent_at 5 days before paid_at
      five_days_ago = DateTime.add(now, -5 * 86_400, :second)

      %Reminder{invoice_id: invoice.id}
      |> Reminder.changeset(%{
        step: 1,
        scheduled_at: five_days_ago,
        status: "sent"
      })
      |> Ecto.Changeset.put_change(:sent_at, five_days_ago)
      |> Repo.insert!()

      result = Reminders.avg_days_to_payment(user.id)
      assert length(result) >= 1

      step1 = Enum.find(result, &(&1.step == 1))
      assert step1 != nil
      assert step1.avg_days == 5.0
      assert step1.sample_size == 1
    end

    test "returns empty list when no paid invoices with reminders" do
      user = create_user()
      _invoice = create_sent_invoice(user)

      result = Reminders.avg_days_to_payment(user.id)
      assert result == []
    end
  end

  describe "reminder_effectiveness/1" do
    test "returns overall and per-step stats" do
      user = create_user()
      invoice = create_sent_invoice(user)

      # Create sent reminders with tracking data
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %Reminder{invoice_id: invoice.id}
      |> Reminder.changeset(%{step: 1, scheduled_at: now, status: "sent"})
      |> Ecto.Changeset.put_change(:sent_at, now)
      |> Ecto.Changeset.put_change(:opened_at, now)
      |> Ecto.Changeset.put_change(:open_count, 1)
      |> Repo.insert!()

      %Reminder{invoice_id: invoice.id}
      |> Reminder.changeset(%{step: 2, scheduled_at: now, status: "sent"})
      |> Ecto.Changeset.put_change(:sent_at, now)
      |> Repo.insert!()

      effectiveness = Reminders.reminder_effectiveness(user.id)

      assert effectiveness.total_sent == 2
      assert effectiveness.total_opened == 1
      assert effectiveness.total_clicked == 0
      assert effectiveness.overall_open_rate == 50.0
      assert effectiveness.overall_click_rate == 0.0
      assert is_list(effectiveness.by_step)
      assert is_list(effectiveness.avg_days_to_payment)
    end
  end

  describe "list_reminders_for_invoice/1" do
    test "returns reminders ordered by step" do
      user = create_user()
      invoice = create_sent_invoice(user)

      create_reminder(invoice, 3)
      create_reminder(invoice, 1)
      create_reminder(invoice, 2)

      reminders = Reminders.list_reminders_for_invoice(invoice.id)
      steps = Enum.map(reminders, & &1.step)
      assert steps == [1, 2, 3]
    end
  end

  describe "send_manual_reminder/2 custom message (AMI-29)" do
    test "persists custom subject and body on the reminder" do
      user = create_user()
      invoice = create_sent_invoice(user)

      assert {:ok, reminder} =
               Reminders.send_manual_reminder(invoice, %{
                 subject: "긴급: 결제 부탁드립니다",
                 body: "안녕하세요, {{client_name}}님. {{amount}} 결제 부탁드립니다."
               })

      stored = Repo.get!(Reminder, reminder.id)
      assert stored.email_subject == "긴급: 결제 부탁드립니다"
      assert stored.email_body == "안녕하세요, {{client_name}}님. {{amount}} 결제 부탁드립니다."
    end

    test "accepts string-keyed custom message map" do
      user = create_user()
      invoice = create_sent_invoice(user)

      assert {:ok, reminder} =
               Reminders.send_manual_reminder(invoice, %{
                 "subject" => "안내",
                 "body" => "본문"
               })

      stored = Repo.get!(Reminder, reminder.id)
      assert stored.email_subject == "안내"
      assert stored.email_body == "본문"
    end

    test "blank custom message leaves subject/body nil (fallback to default)" do
      user = create_user()
      invoice = create_sent_invoice(user)

      assert {:ok, reminder} =
               Reminders.send_manual_reminder(invoice, %{subject: "  ", body: ""})

      stored = Repo.get!(Reminder, reminder.id)
      assert stored.email_subject == nil
      assert stored.email_body == nil
    end

    test "still works with single-arity call (no custom message)" do
      user = create_user()
      invoice = create_sent_invoice(user)

      assert {:ok, reminder} = Reminders.send_manual_reminder(invoice)
      stored = Repo.get!(Reminder, reminder.id)
      assert stored.email_subject == nil
    end
  end

  describe "reminder templates CRUD (AMI-39)" do
    test "create_template/2 persists a per-step template for the user" do
      user = create_user()

      assert {:ok, template} =
               Reminders.create_template(user.id, %{
                 step: 1,
                 tone: "friendly",
                 subject_template: "{{amount}} 결제 안내",
                 body_template: "{{client_name}}님께"
               })

      assert template.user_id == user.id
      assert template.step == 1
      assert template.subject_template == "{{amount}} 결제 안내"
    end

    test "create_template/2 rejects invalid step" do
      user = create_user()

      assert {:error, changeset} =
               Reminders.create_template(user.id, %{
                 step: 9,
                 tone: "friendly",
                 subject_template: "s",
                 body_template: "b"
               })

      assert errors_on(changeset).step != []
    end

    test "get_template/2 returns the user's template for a step" do
      user = create_user()

      {:ok, _t} =
        Reminders.create_template(user.id, %{
          step: 2,
          tone: "firm",
          subject_template: "s",
          body_template: "b"
        })

      assert %ReminderTemplate{step: 2} = Reminders.get_template(user.id, 2)
      assert Reminders.get_template(user.id, 3) == nil
    end

    test "list_templates/1 returns the user's templates ordered by step" do
      user = create_user()

      {:ok, _} =
        Reminders.create_template(user.id, %{
          step: 3,
          tone: "firm",
          subject_template: "s3",
          body_template: "b3"
        })

      {:ok, _} =
        Reminders.create_template(user.id, %{
          step: 1,
          tone: "friendly",
          subject_template: "s1",
          body_template: "b1"
        })

      steps = user.id |> Reminders.list_templates() |> Enum.map(& &1.step)
      assert steps == [1, 3]
    end

    test "upsert_template/3 creates then updates a single template" do
      user = create_user()

      assert {:ok, created} =
               Reminders.upsert_template(user.id, 1, %{
                 tone: "friendly",
                 subject_template: "old",
                 body_template: "old body"
               })

      assert {:ok, updated} =
               Reminders.upsert_template(user.id, 1, %{
                 tone: "firm",
                 subject_template: "new",
                 body_template: "new body"
               })

      assert created.id == updated.id
      assert updated.subject_template == "new"
      assert length(Reminders.list_templates(user.id)) == 1
    end
  end

  describe "conversion_rate/1 (AMI-34)" do
    defp mark_invoice_paid(invoice, paid_at) do
      invoice
      |> Ecto.Changeset.change(
        status: "paid",
        paid_at: paid_at,
        paid_amount: invoice.amount
      )
      |> Repo.update!()
    end

    defp insert_sent_reminder(invoice, step, sent_at) do
      %Reminder{invoice_id: invoice.id}
      |> Reminder.changeset(%{step: step, scheduled_at: sent_at, status: "sent"})
      |> Ecto.Changeset.put_change(:sent_at, sent_at)
      |> Repo.insert!()
    end

    test "computes overall and per-step conversion rate" do
      user = create_user()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      sent_at = DateTime.add(now, -5 * 86_400, :second)

      # Invoice 1: reminded (step 1) and then paid -> converted
      inv1 = create_sent_invoice(user)
      insert_sent_reminder(inv1, 1, sent_at)
      mark_invoice_paid(inv1, now)

      # Invoice 2: reminded (step 1) but not paid -> not converted
      inv2 = create_sent_invoice(user)
      insert_sent_reminder(inv2, 1, sent_at)

      result = Reminders.conversion_rate(user.id)

      # overall: 1 of 2 reminded invoices paid = 50%
      assert result.overall_reminded == 2
      assert result.overall_converted == 1
      assert result.overall_conversion_rate == 50.0

      step1 = Enum.find(result.by_step, &(&1.step == 1))
      assert step1.reminded == 2
      assert step1.converted == 1
      assert step1.conversion_rate == 50.0
    end

    test "only counts payment that occurred after the reminder was sent" do
      user = create_user()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Paid BEFORE the reminder was sent -> not a conversion
      inv = create_sent_invoice(user)
      paid_at = DateTime.add(now, -10 * 86_400, :second)
      reminder_sent_at = DateTime.add(now, -5 * 86_400, :second)
      mark_invoice_paid(inv, paid_at)
      insert_sent_reminder(inv, 1, reminder_sent_at)

      result = Reminders.conversion_rate(user.id)

      assert result.overall_reminded == 1
      assert result.overall_converted == 0
      assert result.overall_conversion_rate == 0.0
    end

    test "deduplicates invoices reminded multiple times at the same step" do
      user = create_user()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      sent_at = DateTime.add(now, -5 * 86_400, :second)

      inv = create_sent_invoice(user)
      insert_sent_reminder(inv, 1, sent_at)
      insert_sent_reminder(inv, 2, sent_at)
      mark_invoice_paid(inv, now)

      result = Reminders.conversion_rate(user.id)

      # One unique invoice reminded, one converted
      assert result.overall_reminded == 1
      assert result.overall_converted == 1
      assert result.overall_conversion_rate == 100.0
    end

    test "returns zeros when no reminders sent" do
      user = create_user()
      _invoice = create_sent_invoice(user)

      result = Reminders.conversion_rate(user.id)

      assert result.overall_reminded == 0
      assert result.overall_converted == 0
      assert result.overall_conversion_rate == 0.0
      assert result.by_step == []
    end
  end

  describe "reminder_effectiveness/1 includes conversion (AMI-34)" do
    test "surfaces conversion_rate inside effectiveness map" do
      user = create_user()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      sent_at = DateTime.add(now, -3 * 86_400, :second)

      inv = create_sent_invoice(user)

      %Reminder{invoice_id: inv.id}
      |> Reminder.changeset(%{step: 1, scheduled_at: sent_at, status: "sent"})
      |> Ecto.Changeset.put_change(:sent_at, sent_at)
      |> Repo.insert!()

      inv
      |> Ecto.Changeset.change(status: "paid", paid_at: now, paid_amount: inv.amount)
      |> Repo.update!()

      effectiveness = Reminders.reminder_effectiveness(user.id)

      assert Map.has_key?(effectiveness, :overall_conversion_rate)
      assert effectiveness.overall_conversion_rate == 100.0
      assert is_list(effectiveness.conversion_by_step)
    end
  end
end
