defmodule AutoMyInvoice.ApiKeys do
  @moduledoc """
  Pro 플랜 API 키 관리 Context.

  키 생성/조회/폐기 및 인증을 담당합니다. 원본 키는 생성 시 한 번만 반환되며
  DB에는 SHA-256 해시만 저장됩니다(users_tokens 와 동일한 방식).
  """

  import Ecto.Query

  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.Accounts.{ApiKey, User}

  @rand_size 24
  @hash_algorithm :sha256
  @prefix "ami_"

  ## 생성

  @spec generate_api_key(User.t(), map()) ::
          {:ok, %{api_key: ApiKey.t(), raw_key: String.t()}} | {:error, Ecto.Changeset.t()}
  def generate_api_key(%User{} = user, attrs) do
    raw_key = @prefix <> Base.url_encode64(:crypto.strong_rand_bytes(@rand_size), padding: false)

    api_attrs = %{
      user_id: user.id,
      name: attrs |> normalize_keys() |> Map.get("name"),
      hashed_key: hash(raw_key),
      prefix: String.slice(raw_key, 0, 8)
    }

    %ApiKey{}
    |> ApiKey.changeset(api_attrs)
    |> Repo.insert()
    |> case do
      {:ok, api_key} -> {:ok, %{api_key: api_key, raw_key: raw_key}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  ## 조회

  @spec list_api_keys(User.t()) :: [ApiKey.t()]
  def list_api_keys(%User{} = user) do
    from(k in ApiKey,
      where: k.user_id == ^user.id,
      where: is_nil(k.revoked_at),
      order_by: [desc: k.inserted_at]
    )
    |> Repo.all()
  end

  ## 폐기

  @spec revoke_api_key(User.t(), binary()) :: {:ok, ApiKey.t()} | {:error, :not_found}
  def revoke_api_key(%User{} = user, key_id) do
    case Repo.get_by(ApiKey, id: key_id, user_id: user.id) do
      nil ->
        {:error, :not_found}

      %ApiKey{} = key ->
        key
        |> ApiKey.changeset(%{revoked_at: DateTime.truncate(DateTime.utc_now(), :second)})
        |> Repo.update()
    end
  end

  ## 인증

  @spec authenticate(String.t()) :: {:ok, User.t()} | {:error, :invalid}
  def authenticate(raw_key) when is_binary(raw_key) do
    hashed = hash(raw_key)

    case Repo.get_by(ApiKey, hashed_key: hashed) do
      %ApiKey{revoked_at: nil} = key ->
        touch_last_used(key)
        {:ok, Accounts.get_user!(key.user_id)}

      _ ->
        {:error, :invalid}
    end
  end

  def authenticate(_), do: {:error, :invalid}

  ## Private

  defp touch_last_used(%ApiKey{} = key) do
    key
    |> ApiKey.changeset(%{last_used_at: DateTime.truncate(DateTime.utc_now(), :second)})
    |> Repo.update()
  end

  defp hash(raw_key), do: :crypto.hash(@hash_algorithm, raw_key)

  defp normalize_keys(attrs) do
    Map.new(attrs, fn {k, v} -> {to_string(k), v} end)
  end
end
