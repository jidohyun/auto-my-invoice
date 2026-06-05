defmodule AutoMyInvoice.Notifications do
  @moduledoc """
  푸시 알림 Context (AMI-41/72).

  디바이스 토큰 등록/조회/정리와, 사용자의 모든 디바이스로 푸시를
  팬아웃하는 책임을 가진다. 실제 전송은 설정된 dispatcher 구현체에
  위임하며, 기본값은 외부 자격증명이 없어도 동작하는 `LogDispatcher`다.
  """

  import Ecto.Query

  require Logger

  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Notifications.{Device, LogDispatcher, PushDispatcher}

  # 90일 이상 갱신되지 않은 토큰은 만료된 것으로 간주
  @stale_after_days 90

  ## 디바이스 등록 / 조회 / 정리

  @doc """
  토큰 기준 upsert로 디바이스를 등록한다.

  동일 토큰이 이미 존재하면 소유자(user_id)/플랫폼/last_seen_at을
  갱신한다. (기기 초기화 후 다른 계정에 동일 토큰이 재할당되는 경우 포함)
  """
  @spec register_device(binary(), map()) :: {:ok, Device.t()} | {:error, Ecto.Changeset.t()}
  def register_device(user_id, attrs) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    changeset =
      %Device{}
      |> Device.changeset(normalize_attrs(attrs))
      |> Ecto.Changeset.put_change(:user_id, user_id)
      |> Ecto.Changeset.put_change(:last_seen_at, now)

    with {:ok, platform} <- Ecto.Changeset.fetch_change(changeset, :platform) do
      Repo.insert(changeset,
        on_conflict: [
          set: [user_id: user_id, platform: platform, last_seen_at: now, updated_at: now]
        ],
        conflict_target: :token,
        returning: true
      )
    else
      # platform missing/invalid — let the changeset surface validation errors
      :error -> Repo.insert(changeset)
    end
  end

  @doc "사용자의 모든 디바이스 (최근 갱신 순)"
  @spec list_user_devices(binary()) :: [Device.t()]
  def list_user_devices(user_id) do
    from(d in Device,
      where: d.user_id == ^user_id,
      order_by: [desc: d.last_seen_at]
    )
    |> Repo.all()
  end

  @doc "사용자의 특정 토큰 디바이스 등록 해제. 없으면 `{:error, :not_found}`."
  @spec unregister_device(binary(), String.t()) :: {:ok, Device.t()} | {:error, :not_found}
  def unregister_device(user_id, token) do
    case Repo.get_by(Device, user_id: user_id, token: token) do
      nil -> {:error, :not_found}
      %Device{} = device -> Repo.delete(device)
    end
  end

  @doc """
  오래된(stale) 디바이스 토큰을 일괄 삭제한다.

  `last_seen_at`이 `days` 일보다 오래된 레코드를 제거하고, 삭제된
  개수를 반환한다.
  """
  @spec delete_stale_devices(non_neg_integer()) :: {non_neg_integer(), nil}
  def delete_stale_devices(days \\ @stale_after_days) do
    cutoff = DateTime.add(DateTime.utc_now(), -days * 86_400, :second)

    from(d in Device, where: d.last_seen_at < ^cutoff)
    |> Repo.delete_all()
  end

  ## 푸시 팬아웃

  @doc """
  사용자의 모든 디바이스로 푸시를 전송한다.

  설정된 dispatcher에 디바이스별로 위임하며, 개별 실패는 로깅 후
  건너뛴다(이메일 등 다른 알림 경로를 막지 않기 위해 항상 `:ok`).
  반환값은 `{:ok, delivered_count}`.
  """
  @spec push_to_user(binary(), PushDispatcher.payload()) :: {:ok, non_neg_integer()}
  def push_to_user(user_id, payload) do
    delivered =
      user_id
      |> list_user_devices()
      |> Enum.map(&deliver_one(&1, payload))
      |> Enum.count(&(&1 == :ok))

    {:ok, delivered}
  end

  ## 내부

  defp deliver_one(device, payload) do
    case dispatcher().deliver(device, payload) do
      {:ok, _receipt} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Notifications: push delivery failed for device #{device.id}: #{inspect(reason)}"
        )

        :error
    end
  rescue
    e ->
      Logger.error("Notifications: dispatcher crashed for device #{device.id}: #{inspect(e)}")
      :error
  end

  @doc "현재 설정된 push dispatcher 구현체 (기본 `LogDispatcher`)."
  @spec dispatcher() :: module()
  def dispatcher do
    :auto_my_invoice
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:dispatcher, LogDispatcher)
  end

  defp normalize_attrs(attrs) do
    %{
      "token" => attrs["token"] || attrs[:token],
      "platform" => attrs["platform"] || attrs[:platform]
    }
  end
end
