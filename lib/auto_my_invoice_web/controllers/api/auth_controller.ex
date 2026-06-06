defmodule AutoMyInvoiceWeb.Api.AuthController do
  use AutoMyInvoiceWeb, :controller

  alias AutoMyInvoice.Accounts
  alias AutoMyInvoiceWeb.Api.{JsonHelpers, FallbackController}
  alias AutoMyInvoiceWeb.Plugs.ApiAuth

  action_fallback FallbackController

  def register(conn, %{"email" => _, "password" => _} = params) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        token = ApiAuth.sign_token(user.id)

        conn
        |> put_status(:created)
        |> json(%{data: %{token: token, user: JsonHelpers.render_user(user)}})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        {:error, :unauthorized}

      user ->
        token = ApiAuth.sign_token(user.id)
        json(conn, %{data: %{token: token, user: JsonHelpers.render_user(user)}})
    end
  end

  def refresh(conn, _params) do
    user = conn.assigns.current_user
    token = ApiAuth.sign_token(user.id)
    json(conn, %{data: %{token: token, user: JsonHelpers.render_user(user)}})
  end

  # NOTE: Mobile Google ID-token login (POST /api/v1/auth/google) is intentionally
  # not wired up. The previous google/2 + verify_google_id_token/1 were a stub that
  # always returned {:error, :invalid_token}, so the endpoint never worked (Elixir
  # 1.20 type inference flagged the unreachable {:ok, claims} clause). The route has
  # been removed; re-add google/2 with real Google ID-token JWT verification
  # (validate signature against Google's public keys + aud/exp claims) to restore it.
  # Web OAuth (Ueberauth via UserOauthController) is separate and unaffected.

  def logout(conn, _params) do
    conn
    |> put_status(:no_content)
    |> text("")
  end
end
