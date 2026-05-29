defmodule AutoMyInvoiceWeb.Plugs.ApiAuth do
  @moduledoc "Bearer token authentication plug for REST API endpoints."

  import Plug.Conn

  alias AutoMyInvoice.{Accounts, ApiKeys}

  # 30 days
  @max_age 86_400 * 30

  # Pro plan API keys (AMI-46) carry this prefix and are looked up by hash.
  @api_key_prefix "ami_"

  def init(opts), do: opts

  def call(conn, _opts) do
    case authenticate(conn) do
      {:ok, user, token} ->
        conn
        |> assign(:current_user, user)
        |> assign(:api_token, token)

      :error ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{
          error: %{code: "unauthorized", message: "Invalid or missing token"}
        })
        |> halt()
    end
  end

  defp authenticate(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> authenticate_token(token)
      _ -> :error
    end
  end

  defp authenticate_token(@api_key_prefix <> _ = token) do
    case ApiKeys.authenticate(token) do
      {:ok, user} -> {:ok, user, token}
      {:error, _} -> :error
    end
  end

  defp authenticate_token(token) do
    with {:ok, user_id} <- verify_token(token),
         user when not is_nil(user) <- Accounts.get_user!(user_id) do
      {:ok, user, token}
    else
      _ -> :error
    end
  end

  @doc "Signs an API token for the given user ID."
  @spec sign_token(binary()) :: binary()
  def sign_token(user_id) do
    Phoenix.Token.sign(AutoMyInvoiceWeb.Endpoint, "api_auth", user_id)
  end

  @doc "Verifies an API token and returns the user ID."
  @spec verify_token(binary()) :: {:ok, binary()} | {:error, atom()}
  def verify_token(token) do
    Phoenix.Token.verify(AutoMyInvoiceWeb.Endpoint, "api_auth", token, max_age: @max_age)
  end
end
