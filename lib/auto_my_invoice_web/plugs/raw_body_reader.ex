defmodule AutoMyInvoiceWeb.Plugs.RawBodyReader do
  @moduledoc """
  Custom body reader that caches the raw request body for webhook signature verification.

  Usage in endpoint.ex:
    plug Plug.Parsers, body_reader: {AutoMyInvoiceWeb.Plugs.RawBodyReader, :read_body, []}
  """

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = Plug.Conn.assign(conn, :raw_body, body)
        {:ok, body, conn}

      {:more, body, conn} ->
        conn = Plug.Conn.assign(conn, :raw_body, body)
        {:more, body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
