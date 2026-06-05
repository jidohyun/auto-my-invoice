defmodule AutoMyInvoice.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:teams, [:owner_id])

    create table(:team_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false

      # Null until an invited user registers / accepts.
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      # Email the invitation was sent to (the canonical identity of a member).
      add :email, :string, null: false

      # one of: owner, member
      add :role, :string, null: false, default: "member"

      # one of: pending, active
      add :status, :string, null: false, default: "pending"

      add :invited_at, :utc_datetime
      add :accepted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:team_memberships, [:team_id, :email])
    create index(:team_memberships, [:user_id])
  end
end
