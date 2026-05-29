defmodule AutoMyInvoice.Accounts.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "api_keys" do
    field :name, :string
    field :hashed_key, :binary, redact: true
    field :prefix, :string
    field :last_used_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :user, AutoMyInvoice.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:user_id, :name, :hashed_key, :prefix, :last_used_at, :revoked_at])
    |> validate_required([:user_id, :name, :hashed_key, :prefix])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint(:hashed_key)
  end

  @type t :: %__MODULE__{}
end
