defmodule AutoMyInvoiceWeb.UserOauthController do
  @moduledoc """
  Google/GitHub 소셜 로그인 (Ueberauth).

  `plug Ueberauth` 가 request 단계(`/auth/:provider`)에서 provider 로 리다이렉트하고,
  callback 단계(`/auth/:provider/callback`)에서 결과를 `conn.assigns` 에 넣는다.
  성공 시 이메일 기준으로 기존 계정에 자동 연결하거나 새 계정을 만들고 세션 로그인한다.
  """
  use AutoMyInvoiceWeb, :controller

  plug Ueberauth

  alias AutoMyInvoice.Accounts
  alias AutoMyInvoiceWeb.UserAuth

  # request phase 는 plug Ueberauth 가 provider 리다이렉트로 처리하므로
  # 이 액션에 도달하면(미설정 provider 등) 로그인으로 안내한다.
  def request(conn, _params) do
    conn
    |> put_flash(:error, gettext("소셜 로그인을 사용할 수 없습니다."))
    |> redirect(to: ~p"/users/log_in")
  end

  # 인증 실패(사용자 취소, provider 미설정, 잘못된 state 등)
  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, gettext("소셜 로그인에 실패했습니다. 다시 시도해 주세요."))
    |> redirect(to: ~p"/users/log_in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case oauth_attrs(auth) do
      {:ok, attrs} ->
        handle_user(conn, Accounts.find_or_create_oauth_user(attrs))

      {:error, :no_email} ->
        conn
        |> put_flash(:error, gettext("이메일 정보를 가져오지 못했습니다. 이메일 공개를 허용해 주세요."))
        |> redirect(to: ~p"/users/log_in")
    end
  end

  defp handle_user(conn, {:ok, user}) do
    conn
    |> put_flash(:info, gettext("로그인되었습니다."))
    |> UserAuth.log_in_user(user)
  end

  defp handle_user(conn, {:error, _changeset}) do
    conn
    |> put_flash(:error, gettext("계정을 생성하지 못했습니다."))
    |> redirect(to: ~p"/users/log_in")
  end

  # provider 별 Ueberauth.Auth 구조에서 우리 모델 attrs 로 매핑한다.
  # 이메일이 없으면(GitHub private email 등) 진행하지 않는다.
  defp oauth_attrs(%Ueberauth.Auth{provider: provider, uid: uid, info: info}) do
    email = info && info.email

    cond do
      is_nil(email) or email == "" ->
        {:error, :no_email}

      provider == :google ->
        {:ok, %{email: email, google_uid: to_string(uid), avatar_url: info.image}}

      provider == :github ->
        {:ok, %{email: email, github_uid: to_string(uid), avatar_url: info.image}}

      true ->
        {:error, :no_email}
    end
  end
end
