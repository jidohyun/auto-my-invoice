defmodule AutoMyInvoiceWeb.Plugs.Locale do
  @moduledoc """
  AMI-49: Per-request Gettext locale resolution.

  Resolution order:
    1. logged-in user's `:locale` preference (`conn.assigns.current_user`)
    2. `:locale` already stored in the session
    3. the Gettext default locale ("ko")

  The resolved locale is set on the Gettext backend for the duration of the
  request and persisted to the session so the LiveView `on_mount` callback can
  pick it up when establishing the socket. Korean is the source language, so a
  "ko" locale falls back to the msgids (original Korean strings) untouched.
  """

  import Plug.Conn

  @behaviour Plug

  @supported ~w(ko en ja)
  @session_key "locale"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    locale = resolve_locale(conn)
    Gettext.put_locale(AutoMyInvoiceWeb.Gettext, locale)
    put_session(conn, @session_key, locale)
  end

  @doc """
  Returns the locale for the given conn, normalized to a supported value.
  """
  @spec resolve_locale(Plug.Conn.t()) :: String.t()
  def resolve_locale(conn) do
    user_locale(conn.assigns[:current_user]) ||
      normalize(get_session(conn, @session_key)) ||
      default_locale()
  end

  @doc """
  Supported locales, with the source (Korean) locale first.
  """
  @spec supported() :: [String.t()]
  def supported, do: @supported

  @doc "Default/source locale."
  @spec default_locale() :: String.t()
  def default_locale, do: Gettext.get_locale(AutoMyInvoiceWeb.Gettext)

  defp user_locale(%{locale: locale}), do: normalize(locale)
  defp user_locale(_), do: nil

  defp normalize(locale) when locale in @supported, do: locale
  defp normalize(_), do: nil
end
