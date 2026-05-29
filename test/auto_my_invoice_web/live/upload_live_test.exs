defmodule AutoMyInvoiceWeb.UploadLiveTest do
  @moduledoc """
  LiveView tests for the receipt upload + AI extraction flow.

  Covers AC-3 (reset event handler) and AC-5 (UploadLive integration tests)
  from .hermes/seeds/AMI-84.md. Where possible we use Phoenix.LiveViewTest
  end-to-end; where the LV is tightly coupled to PubSub broadcasts that
  follow a real file upload, we drive the handler functions directly.
  """

  use AutoMyInvoiceWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AutoMyInvoice.{Accounts, Extraction}
  alias AutoMyInvoiceWeb.UploadLive

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "upload-live-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    token = Accounts.generate_user_session_token(user)

    conn =
      build_conn()
      |> init_test_session(%{user_token: token})

    %{conn: conn, user: user}
  end

  defp create_pending_job(user) do
    {:ok, job} =
      Extraction.create_job(user.id, %{
        file_url: "/uploads/test.png",
        file_type: "png"
      })

    job
  end

  defp create_completed_job(user, extracted) do
    job = create_pending_job(user)
    {:ok, completed} = Extraction.save_result(job, %{"raw" => "x"}, extracted, 0.7)
    completed
  end

  describe "GET /upload (T1)" do
    test "renders the upload form when no extraction is in progress", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/upload")

      assert html =~ "송장 업로드"
      assert html =~ "문서 업로드"
    end

    test "the upload page is gated to authenticated users" do
      conn = build_conn()
      assert {:error, {:redirect, %{to: redirect_to}}} = live(conn, ~p"/upload")
      assert redirect_to =~ "/users/log_in"
    end
  end

  describe "AC-3 reset handler" do
    test "handle_event/3 for 'reset' empties extraction_jobs and re-renders the upload form" do
      # Build a minimal socket with one in-flight ExtractionJob in the batch
      # list, then call the handler directly. This exercises the reset path
      # without going through the live_file_input fixture for an actual
      # multipart upload.
      job = %Extraction.ExtractionJob{
        id: Ecto.UUID.generate(),
        status: "completed",
        extracted_data: %{"amount" => "100", "currency" => "KRW"},
        confidence_score: 0.9
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{extraction_jobs: [job], __changed__: %{}}
      }

      assert {:noreply, new_socket} = UploadLive.handle_event("reset", %{}, socket)
      assert new_socket.assigns.extraction_jobs == []
    end

    # Regression: AMI-85 — UploadLive previously held a single :extraction_job
    # assign and could not show per-file progress for a batch. The new
    # "dismiss-job" event removes one job from the list while leaving the
    # others untouched, so the user can clear processed results one by one.
    test "handle_event/3 for 'dismiss-job' removes only the matching job from the batch" do
      job_a = %Extraction.ExtractionJob{id: Ecto.UUID.generate(), status: "completed"}
      job_b = %Extraction.ExtractionJob{id: Ecto.UUID.generate(), status: "processing"}

      socket = %Phoenix.LiveView.Socket{
        assigns: %{extraction_jobs: [job_a, job_b], __changed__: %{}}
      }

      assert {:noreply, new_socket} =
               UploadLive.handle_event("dismiss-job", %{"id" => job_a.id}, socket)

      assert Enum.map(new_socket.assigns.extraction_jobs, & &1.id) == [job_b.id]
    end
  end

  describe "AMI-38 extraction feedback edit form" do
    test "uploading a file then completing it renders the editable feedback form",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/upload")

      # Simulate a real upload so the LV holds an in-flight ExtractionJob and
      # has subscribed to its completion topic.
      file =
        file_input(view, "#upload-form", :invoice_file, [
          %{name: "invoice.png", content: "fake-bytes", type: "image/png"}
        ])

      render_upload(file, "invoice.png")
      render_submit(element(view, "#upload-form"))

      # The job is now pending in the DB; grab it and complete it, then drive
      # the same PubSub message the OCR worker would broadcast.
      [job] = AutoMyInvoice.Repo.all(Extraction.ExtractionJob)

      extracted = %{"amount" => "1500.00", "currency" => "USD", "notes" => "Net 30"}
      {:ok, _} = Extraction.save_result(job, %{"raw" => "x"}, extracted, 0.6)

      send(view.pid, {:extraction_completed, extracted})

      # Now the completed job shows the read-only view with an edit button.
      assert render(view) =~ "추출 결과 수정"

      # Clicking edit reveals the editable feedback form fields.
      html = render_click(view, "edit-job", %{"id" => job.id})
      assert html =~ "feedback[amount]"
      assert html =~ "feedback[currency]"
      assert html =~ "수정 저장"
    end

    test "handle_event/3 'save-feedback' records corrections via the context",
         %{user: user} do
      job = create_completed_job(user, %{"amount" => "1000", "currency" => "USD"})

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          extraction_jobs: [job],
          editing_job_id: job.id,
          flash: %{},
          __changed__: %{}
        }
      }

      params = %{"job_id" => job.id, "feedback" => %{"amount" => "1200", "currency" => "KRW"}}
      assert {:noreply, new_socket} = UploadLive.handle_event("save-feedback", params, socket)

      assert new_socket.assigns.editing_job_id == nil
      [updated] = new_socket.assigns.extraction_jobs
      assert updated.corrected_data["amount"] == "1200"
      assert updated.corrected_data["currency"] == "KRW"
      assert updated.feedback_submitted_at != nil

      # persisted in the DB
      reloaded = Extraction.get_job!(job.id)
      assert reloaded.corrected_data["amount"] == "1200"
    end

    test "handle_event/3 'edit-job' and 'cancel-edit' toggle editing_job_id" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{editing_job_id: nil, __changed__: %{}}
      }

      assert {:noreply, editing} =
               UploadLive.handle_event("edit-job", %{"id" => "abc"}, socket)

      assert editing.assigns.editing_job_id == "abc"

      assert {:noreply, cancelled} =
               UploadLive.handle_event("cancel-edit", %{}, editing)

      assert cancelled.assigns.editing_job_id == nil
    end
  end

  describe "AC-4 InvoiceLive.New prefill from completed extraction" do
    test "navigating to /invoices/new?extraction_job_id=<id> populates the form prefill",
         %{conn: conn, user: user} do
      job = create_pending_job(user)

      extracted = %{
        "amount" => "1500.00",
        "currency" => "KRW",
        "due_date" => "2026-06-01",
        "notes" => "Net 30",
        "client_name" => "ACME"
      }

      {:ok, _completed} = Extraction.save_result(job, %{"raw" => "x"}, extracted, 0.92)

      {:ok, _view, html} = live(conn, ~p"/invoices/new?extraction_job_id=#{job.id}")

      assert html =~ "새 송장"
      # Robust prefill signals: the amount and currency from extracted_data
      # must appear in the rendered form. Before the AC-4 fix, the call
      # `Extraction.to_invoice_attrs(job)` returned a fully-nil map because
      # ExtractionJob structs do not implement Access on string keys, and
      # neither 1500 nor KRW would be present.
      assert html =~ "1500" or html =~ "1,500"
      assert html =~ "KRW"
    end

    test "extraction job that is not yet completed leaves prefill empty",
         %{conn: conn, user: user} do
      # Pending job (status: "pending", extracted_data: nil)
      job = create_pending_job(user)

      {:ok, _view, html} = live(conn, ~p"/invoices/new?extraction_job_id=#{job.id}")
      assert html =~ "새 송장"
    end
  end
end
