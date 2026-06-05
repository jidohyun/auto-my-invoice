defmodule AutoMyInvoice.Repo.Migrations.AddBusinessSettingsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # AMI-25: 기본 통화
      add :default_currency, :string, default: "KRW", null: false
      # AMI-26: 기본 결제조건 (일수, Net 30)
      add :payment_terms, :integer, default: 30, null: false
      # AMI-27: 비즈니스 정보
      add :business_address, :string
      add :business_registration_number, :string
      add :logo_url, :string
      # AMI-28: 송장 번호 접두사
      add :invoice_prefix, :string, default: "INV", null: false
    end
  end
end
