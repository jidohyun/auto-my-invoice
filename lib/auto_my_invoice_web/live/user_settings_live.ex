defmodule AutoMyInvoiceWeb.UserSettingsLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.{ApiKeys, Teams}

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

      <.branding_section
        pro?={@pro?}
        brand_color={@current_user.brand_color}
        brand_form={@brand_form}
      />

      <.team_section
        pro?={@pro?}
        team={@team}
        members={@members}
        invite_form={@invite_form}
      />

      <.api_keys_section
        pro?={@pro?}
        api_keys={@api_keys}
        api_key_form={@api_key_form}
        new_api_key={@new_api_key}
      />
    </div>
    """
  end

  @doc false
  attr :pro?, :boolean, required: true
  attr :brand_color, :string, default: nil
  attr :brand_form, :map, required: true

  def branding_section(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl mt-6" id="branding-section">
      <div class="card-body">
        <h2 class="card-title text-lg mb-1 flex items-center gap-2">
          맞춤 브랜딩 <span class="badge badge-secondary badge-sm">Pro</span>
        </h2>
        <p :if={!@pro?} class="text-sm text-base-content/60">
          Pro 플랜에서 이메일에 적용되는 브랜드 색상을 설정할 수 있습니다.
        </p>

        <.form
          :if={@pro?}
          for={@brand_form}
          id="branding_form"
          phx-change="validate_brand"
          phx-submit="save_brand"
          class="space-y-4"
        >
          <div class="form-control">
            <label class="label" for="brand_brand_color">
              <span class="label-text">브랜드 색상</span>
            </label>
            <input
              type="color"
              name="brand[brand_color]"
              id="brand_brand_color"
              value={@brand_form[:brand_color].value || "#6d28d9"}
              class="input input-bordered h-12 w-24 p-1"
            />
            <label class="label">
              <span class="label-text-alt text-base-content/50">
                리마인더 이메일 버튼과 강조 색상에 적용됩니다
              </span>
            </label>
          </div>

          <div class="form-control">
            <button type="submit" phx-disable-with="저장 중..." class="btn btn-primary btn-sm">
              브랜딩 저장
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @doc false
  attr :pro?, :boolean, required: true
  attr :team, :any, default: nil
  attr :members, :list, default: []
  attr :invite_form, :map, required: true

  def team_section(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl mt-6" id="team-section">
      <div class="card-body">
        <h2 class="card-title text-lg mb-1 flex items-center gap-2">
          팀 관리 <span class="badge badge-secondary badge-sm">Pro</span>
        </h2>
        <p :if={!@pro?} class="text-sm text-base-content/60">
          Pro 플랜에서 팀원을 초대하고 함께 송장을 관리할 수 있습니다.
        </p>

        <div :if={@pro? && is_nil(@team)} class="mt-2">
          <p class="text-sm text-base-content/60 mb-3">아직 팀이 없습니다. 팀을 생성하세요.</p>
          <.form
            for={%{}}
            as={:team}
            id="create_team_form"
            phx-submit="create_team"
            class="flex gap-2"
          >
            <input
              type="text"
              name="team[name]"
              placeholder="팀 이름"
              class="input input-bordered input-sm flex-1"
            />
            <button type="submit" class="btn btn-primary btn-sm">팀 생성</button>
          </.form>
        </div>

        <div :if={@pro? && @team} class="mt-2">
          <p class="font-medium mb-3">{@team.name}</p>

          <ul class="divide-y divide-base-200 mb-4">
            <li :for={m <- @members} class="flex items-center justify-between py-2">
              <div>
                <span class="text-sm">{m.email}</span>
                <span class="badge badge-ghost badge-xs ml-2">{role_label(m.role)}</span>
                <span class="badge badge-outline badge-xs ml-1">{status_label(m.status)}</span>
              </div>
              <button
                :if={m.role != "owner"}
                class="btn btn-ghost btn-xs text-error"
                phx-click="remove_member"
                phx-value-id={m.id}
              >
                제거
              </button>
            </li>
          </ul>

          <.form
            for={@invite_form}
            id="invite_form"
            phx-submit="invite_member"
            class="flex gap-2"
          >
            <input
              type="email"
              name="member[email]"
              placeholder="초대할 이메일"
              class="input input-bordered input-sm flex-1"
            />
            <button type="submit" phx-disable-with="초대 중..." class="btn btn-primary btn-sm">
              멤버 초대
            </button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  @doc false
  attr :pro?, :boolean, required: true
  attr :api_keys, :list, default: []
  attr :api_key_form, :map, required: true
  attr :new_api_key, :string, default: nil

  def api_keys_section(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl mt-6" id="api-keys-section">
      <div class="card-body">
        <h2 class="card-title text-lg mb-1 flex items-center gap-2">
          API 키 <span class="badge badge-secondary badge-sm">Pro</span>
        </h2>
        <p :if={!@pro?} class="text-sm text-base-content/60">
          Pro 플랜에서 REST API 접근용 키를 발급할 수 있습니다.
        </p>

        <div :if={@pro?} class="mt-2">
          <div :if={@new_api_key} class="alert alert-success text-sm mb-4" id="new-api-key">
            <div>
              <p class="font-medium">새 API 키가 생성되었습니다. 지금만 표시됩니다:</p>
              <code class="break-all">{@new_api_key}</code>
            </div>
          </div>

          <ul class="divide-y divide-base-200 mb-4">
            <li :for={k <- @api_keys} class="flex items-center justify-between py-2">
              <div>
                <span class="text-sm font-medium">{k.name}</span>
                <code class="text-xs text-base-content/60 ml-2">{k.prefix}…</code>
              </div>
              <button
                class="btn btn-ghost btn-xs text-error"
                phx-click="revoke_api_key"
                phx-value-id={k.id}
              >
                폐기
              </button>
            </li>
            <li :if={@api_keys == []} class="py-2 text-sm text-base-content/60">
              발급된 키가 없습니다.
            </li>
          </ul>

          <.form
            for={@api_key_form}
            id="api_key_form"
            phx-submit="create_api_key"
            class="flex gap-2"
          >
            <input
              type="text"
              name="api_key[name]"
              placeholder="키 이름 (예: CI 토큰)"
              class="input input-bordered input-sm flex-1"
            />
            <button type="submit" phx-disable-with="생성 중..." class="btn btn-primary btn-sm">
              키 생성
            </button>
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
      |> assign(:pro?, Accounts.plan_allows?(user, :team))
      |> assign(:new_api_key, nil)
      |> assign_form(changeset)
      |> assign_brand_form(Accounts.change_user_profile(user))
      |> assign_team()
      |> assign_api_keys()
      |> assign(:invite_form, to_form(%{}, as: "member"))
      |> assign(:api_key_form, to_form(%{}, as: "api_key"))

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

  ## AMI-47 맞춤 브랜딩

  def handle_event("validate_brand", %{"brand" => brand_params}, socket) do
    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_profile(brand_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_brand_form(socket, changeset)}
  end

  def handle_event("save_brand", %{"brand" => brand_params}, socket) do
    case Accounts.update_profile(socket.assigns.current_user, brand_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(current_user: user)
         |> assign_brand_form(Accounts.change_user_profile(user))
         |> put_flash(:info, "브랜딩이 저장되었습니다.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_brand_form(socket, changeset)}
    end
  end

  ## AMI-45 팀 관리

  def handle_event("create_team", %{"team" => team_params}, socket) do
    case Teams.create_team(socket.assigns.current_user, team_params) do
      {:ok, _team} ->
        {:noreply,
         socket
         |> assign_team()
         |> put_flash(:info, "팀이 생성되었습니다.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "팀을 생성하지 못했습니다.")}
    end
  end

  def handle_event("invite_member", %{"member" => member_params}, socket) do
    case Teams.invite_member(socket.assigns.team, member_params) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> assign_team()
         |> put_flash(:info, "초대 이메일을 보냈습니다.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "초대에 실패했습니다. 이메일을 확인하세요.")}
    end
  end

  def handle_event("remove_member", %{"id" => id}, socket) do
    case Teams.remove_member(socket.assigns.team, id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign_team()
         |> put_flash(:info, "멤버를 제거했습니다.")}

      {:error, :cannot_remove_owner} ->
        {:noreply, put_flash(socket, :error, "소유자는 제거할 수 없습니다.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "멤버를 제거하지 못했습니다.")}
    end
  end

  ## AMI-46 API 키

  def handle_event("create_api_key", %{"api_key" => params}, socket) do
    case ApiKeys.generate_api_key(socket.assigns.current_user, params) do
      {:ok, %{raw_key: raw_key}} ->
        {:noreply,
         socket
         |> assign(:new_api_key, raw_key)
         |> assign_api_keys()
         |> put_flash(:info, "API 키가 생성되었습니다.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "키 이름을 입력하세요.")}
    end
  end

  def handle_event("revoke_api_key", %{"id" => id}, socket) do
    case ApiKeys.revoke_api_key(socket.assigns.current_user, id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:new_api_key, nil)
         |> assign_api_keys()
         |> put_flash(:info, "API 키를 폐기했습니다.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "키를 폐기하지 못했습니다.")}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "profile"))
  end

  defp assign_brand_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, brand_form: to_form(changeset, as: "brand"))
  end

  defp assign_team(socket) do
    if socket.assigns.pro? do
      team = Teams.get_team_for_owner(socket.assigns.current_user)
      members = if team, do: Teams.list_members(team), else: []
      assign(socket, team: team, members: members)
    else
      assign(socket, team: nil, members: [])
    end
  end

  defp assign_api_keys(socket) do
    keys =
      if socket.assigns.pro?,
        do: ApiKeys.list_api_keys(socket.assigns.current_user),
        else: []

    assign(socket, api_keys: keys)
  end

  defp plan_label("free"), do: "무료"
  defp plan_label("starter"), do: "스타터"
  defp plan_label("pro"), do: "프로"
  defp plan_label(other), do: other

  defp role_label("owner"), do: "소유자"
  defp role_label("member"), do: "멤버"
  defp role_label(other), do: other

  defp status_label("active"), do: "활성"
  defp status_label("pending"), do: "대기중"
  defp status_label(other), do: other
end
