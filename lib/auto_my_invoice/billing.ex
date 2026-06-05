defmodule AutoMyInvoice.Billing do
  @moduledoc "구독 플랜 및 빌링 관리 Context"

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Billing.Subscription
  alias AutoMyInvoice.Accounts

  ## 구독 활성화 (Webhook)

  @spec activate_subscription(map()) :: :ok | {:error, term()}
  def activate_subscription(data) do
    user_id = get_in(data, ["custom_data", "user_id"])
    plan = get_in(data, ["custom_data", "plan"])

    if is_nil(user_id) or is_nil(plan) do
      {:error, :missing_custom_data}
    else
      activate_subscription_impl(user_id, data, plan)
    end
  end

  defp activate_subscription_impl(user_id, data, plan) do
    with {:ok, _sub} <- create_or_update_subscription(user_id, data, plan),
         user <- Accounts.get_user!(user_id),
         {:ok, _user} <-
           Accounts.update_profile(user, %{
             plan: plan,
             paddle_customer_id: data["customer_id"]
           }) do
      :ok
    end
  end

  ## 구독 취소 (Webhook)

  @spec cancel_subscription(map()) :: :ok
  def cancel_subscription(data) do
    sub_id = data["id"]

    case get_subscription_by_paddle_id(sub_id) do
      %Subscription{} = sub ->
        sub
        |> Subscription.changeset(%{
          status: "cancelled",
          cancelled_at: DateTime.truncate(DateTime.utc_now(), :second)
        })
        |> Repo.update()

        :ok

      nil ->
        :ok
    end
  end

  ## 구독 업데이트 (Webhook)

  @spec update_subscription(map()) :: :ok
  def update_subscription(data) do
    sub_id = data["id"]

    case get_subscription_by_paddle_id(sub_id) do
      %Subscription{} = sub ->
        sub
        |> Subscription.changeset(%{
          status: data["status"],
          current_period_start:
            parse_datetime(get_in(data, ["current_billing_period", "starts_at"])),
          current_period_end: parse_datetime(get_in(data, ["current_billing_period", "ends_at"]))
        })
        |> Repo.update()

        :ok

      nil ->
        :ok
    end
  end

  ## 다운그레이드 (AMI-48)
  #
  # Pro → Starter → Free 방향으로만 허용하며, 팀/API 키 등 Pro 전용 데이터는
  # 삭제하지 않고 보존합니다. 플랜 문자열만 변경하여 plan_allows?/2 가 해당
  # 기능 접근을 자동으로 차단하도록 합니다(데이터는 재업그레이드 시 복원).

  @plan_rank %{"free" => 0, "starter" => 1, "pro" => 2}

  @spec downgrade_plan(AutoMyInvoice.Accounts.User.t(), String.t()) ::
          {:ok, AutoMyInvoice.Accounts.User.t()}
          | {:error, :invalid_plan | :not_a_downgrade | Ecto.Changeset.t()}
  def downgrade_plan(user, target_plan) do
    current_rank = Map.get(@plan_rank, user.plan)
    target_rank = Map.get(@plan_rank, target_plan)

    cond do
      is_nil(target_rank) ->
        {:error, :invalid_plan}

      is_nil(current_rank) or target_rank >= current_rank ->
        {:error, :not_a_downgrade}

      true ->
        Accounts.update_profile(user, %{plan: target_plan})
    end
  end

  @doc """
  현재 플랜에서 목표 플랜으로 내려갈 때 접근이 제한되는 기능 목록.

  다운그레이드 확인 UI에서 "무엇이 비활성화되는지" 경고를 표시하는 데 사용합니다.
  업그레이드 방향이면 빈 목록을 반환합니다.
  """
  @spec restricted_features(String.t(), String.t()) :: [atom()]
  def restricted_features(current_plan, target_plan) do
    Accounts.features_for_plan(current_plan) -- Accounts.features_for_plan(target_plan)
  end

  ## 조회

  @spec get_active_subscription(binary()) :: Subscription.t() | nil
  def get_active_subscription(user_id) do
    from(s in Subscription,
      where: s.user_id == ^user_id,
      where: s.status == "active",
      order_by: [desc: s.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  ## 플랜 정보 및 사용량

  @plans %{
    "free" => %{name: "Free", monthly_invoices: 3, price: 0},
    "starter" => %{name: "Starter", monthly_invoices: :unlimited, price: 9},
    "pro" => %{name: "Pro", monthly_invoices: :unlimited, price: 29}
  }

  @spec plans() :: map()
  def plans, do: @plans

  @spec plans_ordered() :: [{String.t(), map()}]
  def plans_ordered do
    @plans
    |> Enum.sort_by(fn {_id, plan} -> plan.price end)
  end

  @spec plan_info(String.t()) :: map()
  def plan_info(plan), do: Map.get(@plans, plan, @plans["free"])

  @spec usage_summary(binary()) :: map()
  def usage_summary(user_id) do
    user = Accounts.get_user!(user_id)
    info = plan_info(user.plan)
    count = invoice_count_this_month(user_id)
    limit = info.monthly_invoices

    %{
      plan: user.plan,
      plan_name: info.name,
      invoices_used: count,
      invoices_limit: limit,
      can_create: limit == :unlimited or count < limit,
      usage_percent: if(limit == :unlimited, do: 0, else: min(round(count / limit * 100), 100))
    }
  end

  defp invoice_count_this_month(user_id) do
    start_of_month = Date.utc_today() |> Date.beginning_of_month()

    from(i in "invoices",
      where: i.user_id == type(^user_id, :binary_id),
      where: fragment("?::date", i.inserted_at) >= ^start_of_month,
      select: count(i.id)
    )
    |> Repo.one()
  end

  ## Private

  defp create_or_update_subscription(user_id, data, plan) do
    attrs = %{
      paddle_subscription_id: data["id"],
      paddle_customer_id: data["customer_id"],
      plan: plan,
      status: "active",
      current_period_start: parse_datetime(get_in(data, ["current_billing_period", "starts_at"])),
      current_period_end: parse_datetime(get_in(data, ["current_billing_period", "ends_at"]))
    }

    case get_subscription_by_paddle_id(data["id"]) do
      nil ->
        %Subscription{user_id: user_id}
        |> Subscription.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> Subscription.changeset(attrs)
        |> Repo.update()
    end
  end

  defp get_subscription_by_paddle_id(nil), do: nil

  defp get_subscription_by_paddle_id(paddle_id) do
    Repo.get_by(Subscription, paddle_subscription_id: paddle_id)
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
