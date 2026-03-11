defmodule AutoMyInvoiceWeb.InvoicePDFController do
  use AutoMyInvoiceWeb, :controller

  alias AutoMyInvoice.Invoices
  alias AutoMyInvoice.PDF.InvoicePDF

  def download(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    invoice = Invoices.get_invoice!(user.id, id)

    case InvoicePDF.generate(%{invoice: invoice, client: invoice.client}) do
      {:ok, pdf_data} ->
        filename = "#{invoice.invoice_number}.pdf"
        pdf_binary = Base.decode64!(pdf_data)

        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, pdf_binary)

      {:error, reason} ->
        conn
        |> put_flash(:error, "PDF generation failed: #{reason}")
        |> redirect(to: ~p"/invoices/#{id}")
    end
  end
end
