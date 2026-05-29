defmodule AutoMyInvoice.Accounts.TeamMembership do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(owner member)
  @statuses ~w(pending active)

  schema "team_memberships" do
    field :email, :string
    field :role, :string, default: "member"
    field :status, :string, default: "pending"
    field :invited_at, :utc_datetime
    field :accepted_at, :utc_datetime

    belongs_to :team, AutoMyInvoice.Accounts.Team
    belongs_to :user, AutoMyInvoice.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:team_id, :user_id, :email, :role, :status, :invited_at, :accepted_at])
    |> validate_required([:team_id, :email, :role, :status])
    |> update_change(:email, &normalize_email/1)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:team_id, :email],
      name: :team_memberships_team_id_email_index,
      message: "이미 초대된 이메일입니다"
    )
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  @spec roles() :: [String.t()]
  def roles, do: @roles

  @type t :: %__MODULE__{}
end
