defmodule AutoMyInvoice.Clients.Client do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "clients" do
    field :name, :string
    field :email, :string
    field :company, :string
    field :phone, :string
    field :address, :string
    field :timezone, :string, default: "UTC"
    field :notes, :string

    field :avg_payment_days, :integer
    field :total_invoiced, :decimal, default: Decimal.new(0)
    field :total_paid, :decimal, default: Decimal.new(0)

    belongs_to :user, AutoMyInvoice.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name, :email]
  @optional_fields [:company, :phone, :address, :timezone, :notes]

  def changeset(client, attrs) do
    client
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:name, min: 1, max: 200)
    |> validate_length(:company, max: 200)
    |> validate_length(:notes, max: 2000)
    |> validate_timezone(:timezone)
    |> unique_constraint([:user_id, :email], message: "이미 등록된 클라이언트 이메일입니다")
  end

  # Reject anything that is not a real IANA timezone. The client timezone is fed
  # straight into DateTime.from_naive/2 when scheduling reminders, so an invalid
  # value (e.g. "Asia/Seoul (KST)") would silently fall back to UTC and deliver
  # reminders at the wrong local time.
  defp validate_timezone(changeset, field) do
    validate_change(changeset, field, fn ^field, tz ->
      case DateTime.now(tz) do
        {:error, :time_zone_not_found} -> [{field, "유효한 시간대가 아닙니다"}]
        _ -> []
      end
    end)
  end

  def stats_changeset(client, attrs) do
    client
    |> cast(attrs, [:avg_payment_days, :total_invoiced, :total_paid])
  end
end
