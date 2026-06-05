defmodule AutoMyInvoice.Reminders.TemplateRenderer do
  @moduledoc """
  Interpolates `{{variable}}` placeholders in reminder templates (AMI-39).

  Supported variables: `client_name`, `amount`, `due_date`,
  `invoice_number`, `days_overdue`. Unknown placeholders are left
  untouched so authors can spot typos in the preview. Whitespace inside
  the braces is tolerated, e.g. `{{ client_name }}`.
  """

  @placeholder_re ~r/\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}/

  @doc """
  Replaces every `{{key}}` in `template` with the matching value from
  `vars` (a map keyed by atom or string). Non-string values are
  converted with `to_string/1`. Returns the original placeholder when no
  matching key is present.
  """
  @spec render(String.t() | nil, map()) :: String.t()
  def render(nil, _vars), do: ""

  def render(template, vars) when is_binary(template) do
    normalized = normalize(vars)

    Regex.replace(@placeholder_re, template, fn whole, key ->
      case Map.fetch(normalized, key) do
        {:ok, value} -> to_string(value)
        :error -> whole
      end
    end)
  end

  defp normalize(vars) do
    Map.new(vars, fn {k, v} -> {to_string(k), v} end)
  end
end
