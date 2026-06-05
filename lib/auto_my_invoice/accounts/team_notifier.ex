defmodule AutoMyInvoice.Accounts.TeamNotifier do
  @moduledoc "Team-related transactional emails (e.g. member invitations)."

  import Swoosh.Email

  alias AutoMyInvoice.Mailer

  @from_name "AutoMyInvoice"

  @spec deliver_invitation(String.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_invitation(email, team_name) do
    new()
    |> to({email, email})
    |> from({@from_name, from_email()})
    |> subject("[AutoMyInvoice] #{team_name} 팀에 초대되었습니다")
    |> text_body(invitation_text(team_name))
    |> html_body(invitation_html(team_name))
    |> Mailer.deliver()
  end

  defp invitation_text(team_name) do
    """
    안녕하세요,

    #{team_name} 팀에서 AutoMyInvoice 팀 멤버로 초대했습니다.
    아래 주소에서 회원가입 후 팀에 합류하세요.

    #{signup_url()}

    본인이 요청한 것이 아니라면 이 메일을 무시하세요.
    """
  end

  defp invitation_html(team_name) do
    """
    <p>안녕하세요,</p>
    <p><strong>#{team_name}</strong> 팀에서 AutoMyInvoice 팀 멤버로 초대했습니다.
    아래 버튼에서 회원가입 후 팀에 합류하세요.</p>
    <p><a href="#{signup_url()}" style="display:inline-block;padding:12px 24px;background:#6d28d9;color:#fff;text-decoration:none;border-radius:6px;">팀 합류하기</a></p>
    <p>본인이 요청한 것이 아니라면 이 메일을 무시하세요.</p>
    """
  end

  defp signup_url do
    base = Application.get_env(:auto_my_invoice, :app_base_url, "https://automyinvoice.local")
    base <> "/users/register"
  end

  defp from_email do
    Application.get_env(:auto_my_invoice, :sender_email, "noreply@automyinvoice.local")
  end
end
