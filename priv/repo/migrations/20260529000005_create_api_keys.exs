defmodule AutoMyInvoice.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :name, :string, null: false

      # SHA-256 hash of the raw key. The raw key is shown once at creation
      # and never stored, mirroring the users_tokens hashing approach.
      add :hashed_key, :binary, null: false

      # First 8 chars of the raw key, shown so the user can identify it
      # in the list without exposing the secret.
      add :prefix, :string, null: false

      add :last_used_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_keys, [:hashed_key])
    create index(:api_keys, [:user_id])
  end
end
