defmodule AutoMyInvoice.Notifications.PushNotifier do
  @moduledoc """
  도메인 이벤트를 한국어 푸시 페이로드로 변환해 사용자의 모든
  디바이스로 팬아웃하는 얇은 헬퍼 (AMI-41/72).

  이메일 알림 등 기존 경로를 막지 않도록, 모든 함수는 부수효과를
  안전하게 처리하고 항상 `{:ok, delivered_count}`를 반환한다.
  """

  alias AutoMyInvoice.Notifications

  @doc "송장 연체 전환 시 발행자에게 푸시."
  @spec invoice_overdue(map()) :: {:ok, non_neg_integer()}
  def invoice_overdue(%{user_id: user_id} = invoice) do
    Notifications.push_to_user(user_id, %{
      title: "송장 연체",
      body: "송장 #{invoice_label(invoice)}의 결제 기한이 지났습니다.",
      data: %{"type" => "invoice_overdue", "invoice_id" => invoice.id}
    })
  end

  @doc "결제 수령 시 발행자에게 푸시 (전액/부분 결제 모두)."
  @spec payment_received(map()) :: {:ok, non_neg_integer()}
  def payment_received(%{user_id: user_id} = invoice) do
    Notifications.push_to_user(user_id, %{
      title: payment_title(invoice),
      body: "송장 #{invoice_label(invoice)}에 대한 결제가 확인되었습니다.",
      data: %{"type" => "payment_received", "invoice_id" => invoice.id}
    })
  end

  @doc "리마인더 발송 시 발행자에게 푸시."
  @spec reminder_sent(map()) :: {:ok, non_neg_integer()}
  def reminder_sent(%{user_id: user_id} = invoice) do
    Notifications.push_to_user(user_id, %{
      title: "리마인더 발송",
      body: "송장 #{invoice_label(invoice)}의 결제 리마인더를 보냈습니다.",
      data: %{"type" => "reminder_sent", "invoice_id" => invoice.id}
    })
  end

  defp payment_title(%{status: "paid"}), do: "결제 완료"
  defp payment_title(_), do: "부분 결제 수령"

  defp invoice_label(%{invoice_number: number}) when is_binary(number) and number != "",
    do: "##{number}"

  defp invoice_label(_), do: ""
end
