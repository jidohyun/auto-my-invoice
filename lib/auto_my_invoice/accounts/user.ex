defmodule AutoMyInvoice.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :hashed_password, :string, redact: true
    field :password, :string, virtual: true, redact: true
    field :confirmed_at, :naive_datetime

    # 프로필
    field :company_name, :string
    field :timezone, :string, default: "Asia/Seoul"
    field :brand_tone, :string, default: "professional"
    field :brand_color, :string
    field :locale, :string, default: "ko"

    # 비즈니스 설정 (AMI-25/26/27/28)
    field :default_currency, :string, default: "KRW"
    field :payment_terms, :integer, default: 30
    field :business_address, :string
    field :business_registration_number, :string
    field :logo_url, :string
    field :invoice_prefix, :string, default: "INV"

    # OAuth
    field :google_uid, :string
    field :github_uid, :string
    field :avatar_url, :string

    # 구독
    field :plan, :string, default: "free"
    field :paddle_customer_id, :string

    timestamps(type: :utc_datetime)
  end

  @optional_fields [
    :company_name,
    :timezone,
    :brand_tone,
    :brand_color,
    :default_currency,
    :payment_terms,
    :business_address,
    :business_registration_number,
    :logo_url,
    :invoice_prefix,
    :locale,
    :google_uid,
    :github_uid,
    :avatar_url,
    :plan,
    :paddle_customer_id
  ]

  @currencies ~w(KRW USD EUR JPY GBP)
  @payment_terms_options [15, 30, 45, 60]

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password | @optional_fields])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  def oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :google_uid,
      :github_uid,
      :avatar_url,
      :confirmed_at | @optional_fields
    ])
    |> validate_email([])
    |> unique_constraint(:google_uid)
    |> unique_constraint(:github_uid)
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, @optional_fields)
    |> validate_inclusion(:brand_tone, ~w(professional friendly formal))
    |> validate_inclusion(:plan, ~w(free starter pro))
    |> validate_inclusion(:default_currency, @currencies, message: "지원하지 않는 통화입니다")
    |> validate_inclusion(:payment_terms, @payment_terms_options,
      message: "Net 15/30/45/60 중에서 선택하세요"
    )
    |> validate_format(:invoice_prefix, ~r/^[A-Za-z0-9-]{1,10}$/,
      message: "영문/숫자/하이픈 1~10자만 가능합니다"
    )
    |> validate_inclusion(:locale, ~w(ko en ja))
    |> validate_format(:brand_color, ~r/^#[0-9A-Fa-f]{6}$/,
      message: "must be a hex color like #RRGGBB"
    )
  end

  @doc "AMI-25/26/28: 통화·결제조건·접두사 선택 옵션 노출용 헬퍼"
  def currencies, do: @currencies
  def payment_terms_options, do: @payment_terms_options

  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "비밀번호가 일치하지 않습니다")
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, AutoMyInvoice.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end
end
