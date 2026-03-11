defmodule AutoMyInvoiceWeb.PageController do
  use AutoMyInvoiceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
