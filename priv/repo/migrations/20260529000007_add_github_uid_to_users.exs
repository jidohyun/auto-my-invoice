defmodule AutoMyInvoice.Repo.Migrations.AddGithubUidToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # GitHub OAuth uid (Google 은 기존 google_uid). 이메일 기준 자동 계정 연결.
      add :github_uid, :string
    end

    create unique_index(:users, [:github_uid])
  end
end
