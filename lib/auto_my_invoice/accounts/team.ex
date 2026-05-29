defmodule AutoMyInvoice.Accounts.Team do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "teams" do
    field :name, :string

    belongs_to :owner, AutoMyInvoice.Accounts.User
    has_many :memberships, AutoMyInvoice.Accounts.TeamMembership

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :owner_id])
    |> validate_required([:name, :owner_id])
    |> validate_length(:name, min: 1, max: 100)
  end

  @type t :: %__MODULE__{}
end
