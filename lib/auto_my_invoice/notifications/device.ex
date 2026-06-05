defmodule AutoMyInvoice.Notifications.Device do
  @moduledoc "푸시 알림 디바이스 토큰 스키마 (FCM/APNs)"

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @platforms ~w(android ios)

  schema "devices" do
    field :token, :string
    field :platform, :string
    field :last_seen_at, :utc_datetime

    belongs_to :user, AutoMyInvoice.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @required_fields [:token, :platform]

  def changeset(device, attrs) do
    device
    |> cast(attrs, @required_fields ++ [:last_seen_at])
    |> validate_required(@required_fields)
    |> validate_inclusion(:platform, @platforms,
      message: "must be one of: #{Enum.join(@platforms, ", ")}"
    )
    |> validate_length(:token, min: 1, max: 4096)
    |> unique_constraint(:token)
  end

  @doc "Allowed platform values."
  @spec platforms() :: [String.t()]
  def platforms, do: @platforms
end
