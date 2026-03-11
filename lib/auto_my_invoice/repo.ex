defmodule AutoMyInvoice.Repo do
  use Ecto.Repo,
    otp_app: :auto_my_invoice,
    adapter: Ecto.Adapters.Postgres
end
