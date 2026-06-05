defmodule AutoMyInvoiceWeb.ReminderTemplateLive do
  @moduledoc """
  Per-step reminder template editor with live preview (AMI-39).

  Lets a user customize the subject/body of the step 1/2/3 reminder
  emails using `{{client_name}}`, `{{amount}}`, `{{due_date}}` variables.
  A live preview shows the interpolated result with sample data.
  """
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Reminders
  alias AutoMyInvoice.Reminders.{ReminderTemplate, TemplateRenderer}

  @steps [1, 2, 3]

  @step_labels %{
    1 => "1단계 (마감 +1일, 친근한 확인)",
    2 => "2단계 (마감 +7일, 추가 확인)",
    3 => "3단계 (마감 +14일, 최종 통보)"
  }

  @preview_vars %{
    client_name: "홍길동",
    amount: "₩1,200,000",
    due_date: "2026년 05월 20일"
  }

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    templates = templates_by_step(user.id)
    step = 1

    {:ok,
     socket
     |> assign(:page_title, "리마인더 템플릿")
     |> assign(:steps, @steps)
     |> assign(:step_labels, @step_labels)
     |> assign(:preview_vars, @preview_vars)
     |> assign(:templates, templates)
     |> assign(:step, step)
     |> assign_step_form(step, templates)}
  end

  @impl true
  def handle_event("select_step", %{"step" => step_str}, socket) do
    step = String.to_integer(step_str)

    {:noreply,
     socket
     |> assign(:step, step)
     |> assign_step_form(step, socket.assigns.templates)}
  end

  @impl true
  def handle_event("validate", %{"template" => params}, socket) do
    changeset =
      socket.assigns.templates
      |> template_for_step(socket.assigns.step)
      |> Reminders.change_template(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset, as: "template"))
     |> assign(:preview, build_preview(params))}
  end

  @impl true
  def handle_event("save", %{"template" => params}, socket) do
    user = socket.assigns.current_user
    step = socket.assigns.step
    attrs = Map.put(params, "tone", params["tone"] || "friendly")

    case Reminders.upsert_template(user.id, step, attrs) do
      {:ok, _template} ->
        templates = templates_by_step(user.id)

        {:noreply,
         socket
         |> assign(:templates, templates)
         |> assign_step_form(step, templates)
         |> put_flash(:info, "#{step}단계 템플릿이 저장되었습니다.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "template"))}
    end
  end

  defp assign_step_form(socket, step, templates) do
    template = template_for_step(templates, step)
    changeset = Reminders.change_template(template)

    socket
    |> assign(:form, to_form(changeset, as: "template"))
    |> assign(
      :preview,
      build_preview(%{
        "subject_template" => template.subject_template || "",
        "body_template" => template.body_template || ""
      })
    )
  end

  defp build_preview(params) do
    %{
      subject: TemplateRenderer.render(params["subject_template"] || "", @preview_vars),
      body: TemplateRenderer.render(params["body_template"] || "", @preview_vars)
    }
  end

  defp templates_by_step(user_id) do
    user_id
    |> Reminders.list_templates()
    |> Map.new(fn t -> {t.step, t} end)
  end

  defp template_for_step(templates, step) do
    Map.get(templates, step, %ReminderTemplate{step: step, tone: "friendly"})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6">
      <h1 class="text-3xl font-bold mb-2">리마인더 템플릿</h1>
      <p class="text-base-content/60 mb-8">
        단계별 자동 리마인더 이메일의 제목과 본문을 직접 편집할 수 있습니다. <code class="badge badge-ghost badge-sm">{"{{client_name}}"}</code>, <code class="badge badge-ghost badge-sm">{"{{amount}}"}</code>,
        <code class="badge badge-ghost badge-sm">{"{{due_date}}"}</code>
        변수를 사용하면 발송 시 실제 값으로 치환됩니다.
      </p>

      <div role="tablist" class="tabs tabs-boxed mb-6">
        <button
          :for={s <- @steps}
          role="tab"
          class={"tab #{if s == @step, do: "tab-active"}"}
          phx-click="select_step"
          phx-value-step={s}
        >
          {s}단계
        </button>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title text-lg">{@step_labels[@step]}</h2>

            <.form
              for={@form}
              id="template_form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-4"
            >
              <div class="form-control">
                <label class="label" for="template_tone">
                  <span class="label-text">톤</span>
                </label>
                <select
                  name="template[tone]"
                  id="template_tone"
                  class="select select-bordered w-full"
                >
                  <option value="friendly" selected={@form[:tone].value in [nil, "friendly"]}>
                    친근함
                  </option>
                  <option value="gentle" selected={@form[:tone].value == "gentle"}>정중함</option>
                  <option value="firm" selected={@form[:tone].value == "firm"}>단호함</option>
                </select>
              </div>

              <div class="form-control">
                <label class="label" for="template_subject_template">
                  <span class="label-text">제목</span>
                </label>
                <input
                  type="text"
                  name="template[subject_template]"
                  id="template_subject_template"
                  value={@form[:subject_template].value}
                  class="input input-bordered w-full"
                  placeholder="송장 {{amount}} 결제 안내"
                />
              </div>

              <div class="form-control">
                <label class="label" for="template_body_template">
                  <span class="label-text">본문</span>
                </label>
                <textarea
                  name="template[body_template]"
                  id="template_body_template"
                  rows="8"
                  class="textarea textarea-bordered w-full"
                  placeholder="{{client_name}} 담당자님께, {{amount}} 결제를 {{due_date}}까지 부탁드립니다."
                >{@form[:body_template].value}</textarea>
              </div>

              <div class="form-control mt-4">
                <button type="submit" phx-disable-with="저장 중..." class="btn btn-primary">
                  {@step}단계 템플릿 저장
                </button>
              </div>
            </.form>
          </div>
        </div>

        <div class="card bg-base-100 shadow" id="template-preview">
          <div class="card-body">
            <h2 class="card-title text-lg">미리보기</h2>
            <p class="text-sm text-base-content/60">샘플 데이터로 치환된 결과입니다.</p>
            <div class="mt-3">
              <span class="text-sm text-base-content/60">제목</span>
              <p class="font-medium" id="preview-subject">{@preview.subject}</p>
            </div>
            <div class="mt-3">
              <span class="text-sm text-base-content/60">본문</span>
              <p class="whitespace-pre-wrap" id="preview-body">{@preview.body}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
