defmodule AutoMyInvoiceWeb.UserSettingsLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Accounts

  @timezones [
    "Asia/Seoul",
    "Asia/Tokyo",
    "Asia/Shanghai",
    "Asia/Singapore",
    "UTC",
    "America/New_York",
    "America/Chicago",
    "America/Denver",
    "America/Los_Angeles",
    "Europe/London",
    "Europe/Paris",
    "Europe/Berlin",
    "Pacific/Auckland",
    "Australia/Sydney"
  ]

  @brand_tones [
    {"프로페셔널", "professional"},
    {"친근함", "friendly"},
    {"격식 있음", "formal"}
  ]

  # AMI-25: 지원 통화 (KRW 최상단)
  @currencies [
    {"원 (KRW)", "KRW"},
    {"미국 달러 (USD)", "USD"},
    {"유로 (EUR)", "EUR"},
    {"엔 (JPY)", "JPY"},
    {"파운드 (GBP)", "GBP"}
  ]

  # AMI-26: 결제 조건 옵션
  @payment_terms [
    {"Net 15 (15일)", 15},
    {"Net 30 (30일)", 30},
    {"Net 45 (45일)", 45},
    {"Net 60 (60일)", 60}
  ]

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6">
      <h1 class="text-3xl font-bold mb-8">설정</h1>

      <div class="card bg-base-100 shadow-xl mb-6">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">계정</h2>

          <div class="flex items-center gap-4 mb-4">
            <div class="avatar placeholder">
              <div class="bg-primary text-primary-content rounded-full w-12">
                <span class="text-xl">{String.first(@current_user.email)}</span>
              </div>
            </div>
            <div>
              <p class="font-medium">{@current_user.email}</p>
              <div class="badge badge-outline badge-sm mt-1">{plan_label(@current_user.plan)} 플랜</div>
            </div>
          </div>
        </div>
      </div>

      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">프로필</h2>

          <.form
            for={@form}
            id="settings_form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <div class="form-control">
              <label class="label" for="profile_company_name">
                <span class="label-text">회사명</span>
              </label>
              <input
                type="text"
                name="profile[company_name]"
                id="profile_company_name"
                value={@form[:company_name].value}
                class="input input-bordered w-full"
                placeholder="회사명을 입력하세요"
              />
            </div>

            <div class="form-control">
              <label class="label" for="profile_timezone">
                <span class="label-text">시간대</span>
              </label>
              <select
                name="profile[timezone]"
                id="profile_timezone"
                class="select select-bordered w-full"
              >
                <option
                  :for={tz <- @timezones}
                  value={tz}
                  selected={@form[:timezone].value == tz}
                >
                  {tz}
                </option>
              </select>
            </div>

            <div class="form-control">
              <label class="label" for="profile_brand_tone">
                <span class="label-text">브랜드 톤</span>
              </label>
              <select
                name="profile[brand_tone]"
                id="profile_brand_tone"
                class="select select-bordered w-full"
              >
                <option
                  :for={{label, value} <- @brand_tones}
                  value={value}
                  selected={@form[:brand_tone].value == value}
                >
                  {label}
                </option>
              </select>
              <label class="label">
                <span class="label-text-alt text-base-content/50">
                  AI가 생성하는 리마인더 이메일 톤에 반영됩니다
                </span>
              </label>
            </div>

            <div class="divider">송장 기본값</div>

            <div class="form-control">
              <label class="label" for="profile_default_currency">
                <span class="label-text">기본 통화</span>
              </label>
              <select
                name="profile[default_currency]"
                id="profile_default_currency"
                class="select select-bordered w-full"
              >
                <option
                  :for={{label, value} <- @currencies}
                  value={value}
                  selected={@form[:default_currency].value == value}
                >
                  {label}
                </option>
              </select>
              <label class="label">
                <span class="label-text-alt text-base-content/50">
                  새 송장 생성 시 자동으로 채워집니다 (송장별 변경 가능)
                </span>
              </label>
            </div>

            <div class="form-control">
              <label class="label" for="profile_payment_terms">
                <span class="label-text">기본 결제 조건</span>
              </label>
              <select
                name="profile[payment_terms]"
                id="profile_payment_terms"
                class="select select-bordered w-full"
              >
                <option
                  :for={{label, value} <- @payment_terms_options}
                  value={value}
                  selected={to_string(@form[:payment_terms].value) == to_string(value)}
                >
                  {label}
                </option>
              </select>
              <label class="label">
                <span class="label-text-alt text-base-content/50">
                  발행일 + 조건 = 마감일이 자동 계산됩니다
                </span>
              </label>
            </div>

            <div class="form-control">
              <label class="label" for="profile_invoice_prefix">
                <span class="label-text">송장 번호 접두사</span>
              </label>
              <input
                type="text"
                name="profile[invoice_prefix]"
                id="profile_invoice_prefix"
                value={@form[:invoice_prefix].value}
                class="input input-bordered w-full"
                placeholder="INV"
                maxlength="10"
              />
              <label class="label">
                <span class="label-text-alt text-base-content/50">
                  예: MYCO → MYCO-202605-XXXX (영문/숫자/하이픈 1~10자)
                </span>
              </label>
            </div>

            <div class="divider">비즈니스 정보</div>

            <div class="form-control">
              <label class="label" for="profile_business_address">
                <span class="label-text">사업장 주소</span>
              </label>
              <input
                type="text"
                name="profile[business_address]"
                id="profile_business_address"
                value={@form[:business_address].value}
                class="input input-bordered w-full"
                placeholder="서울특별시 ..."
              />
            </div>

            <div class="form-control">
              <label class="label" for="profile_business_registration_number">
                <span class="label-text">사업자등록번호</span>
              </label>
              <input
                type="text"
                name="profile[business_registration_number]"
                id="profile_business_registration_number"
                value={@form[:business_registration_number].value}
                class="input input-bordered w-full"
                placeholder="000-00-00000"
              />
            </div>

            <div class="form-control">
              <label class="label" for="profile_logo_url">
                <span class="label-text">로고 이미지 URL</span>
              </label>
              <input
                type="url"
                name="profile[logo_url]"
                id="profile_logo_url"
                value={@form[:logo_url].value}
                class="input input-bordered w-full"
                placeholder="https://..."
              />
              <label class="label">
                <span class="label-text-alt text-base-content/50">
                  송장 PDF 상단과 이메일 헤더에 표시됩니다
                </span>
              </label>
            </div>

            <div class="form-control mt-6">
              <button type="submit" phx-disable-with="저장 중..." class="btn btn-primary">
                변경사항 저장
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    changeset = Accounts.change_user_profile(user)

    socket =
      socket
      |> assign(:page_title, "설정")
      |> assign(timezones: @timezones, brand_tones: @brand_tones)
      |> assign(currencies: @currencies, payment_terms_options: @payment_terms)
      |> assign_form(changeset)

    {:ok, socket}
  end

  def handle_event("validate", %{"profile" => profile_params}, socket) do
    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_profile(profile_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"profile" => profile_params}, socket) do
    case Accounts.update_profile(socket.assigns.current_user, profile_params) do
      {:ok, user} ->
        changeset = Accounts.change_user_profile(user)

        {:noreply,
         socket
         |> assign(current_user: user)
         |> assign_form(changeset)
         |> put_flash(:info, "설정이 저장되었습니다.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "profile"))
  end

  defp plan_label("free"), do: "무료"
  defp plan_label("starter"), do: "스타터"
  defp plan_label("pro"), do: "프로"
  defp plan_label(other), do: other
end
