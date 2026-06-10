defmodule AutoMyInvoice.Analytics do
  @moduledoc "Analytics Context - collection trends, status distribution, aging, and cashflow forecast"

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Clients
  alias AutoMyInvoice.FxRates
  alias AutoMyInvoice.Invoices.Invoice
  alias AutoMyInvoice.Clients.Client

  # AMI-33: collection probability applied when a client has no payment history yet.
  @default_collection_probability Decimal.new("0.7")

  # AMI-51: invoice statuses considered outstanding for currency breakdown.
  @outstanding_statuses ~w(sent overdue partially_paid)

  @doc """
  Monthly collection trends for the last N months.
  Returns a list of maps with month, invoiced total, collected total, and invoice count.
  """
  @spec monthly_collections(binary(), pos_integer()) :: [map()]
  def monthly_collections(user_id, months \\ 6) do
    cutoff = Date.utc_today() |> Date.beginning_of_month() |> Date.shift(month: -(months - 1))

    invoiced_by_month =
      from(i in Invoice,
        where: i.user_id == ^user_id,
        where: fragment("?::date", i.inserted_at) >= ^cutoff,
        group_by: fragment("to_char(?, 'YYYY-MM')", i.inserted_at),
        select: %{
          month: fragment("to_char(?, 'YYYY-MM')", i.inserted_at),
          invoiced:
            coalesce(
              sum(
                coalesce(
                  i.amount_krw,
                  fragment("CASE WHEN ? = 'KRW' THEN ? ELSE 0 END", i.currency, i.amount)
                )
              ),
              0
            ),
          count: count(i.id)
        }
      )
      |> Repo.all()
      |> Map.new(fn row -> {row.month, row} end)

    collected_by_month =
      from(i in Invoice,
        where: i.user_id == ^user_id,
        where: i.status == "paid",
        where: not is_nil(i.paid_at),
        where: fragment("?::date", i.paid_at) >= ^cutoff,
        group_by: fragment("to_char(?, 'YYYY-MM')", i.paid_at),
        select: %{
          month: fragment("to_char(?, 'YYYY-MM')", i.paid_at),
          collected: coalesce(sum(i.paid_amount), 0)
        }
      )
      |> Repo.all()
      |> Map.new(fn row -> {row.month, row.collected} end)

    generate_month_range(cutoff, months)
    |> Enum.map(fn month_str ->
      invoiced_row = Map.get(invoiced_by_month, month_str, %{invoiced: Decimal.new(0), count: 0})
      collected = Map.get(collected_by_month, month_str, Decimal.new(0))

      %{
        month: month_str,
        invoiced: invoiced_row.invoiced,
        collected: collected,
        count: invoiced_row.count
      }
    end)
  end

  @doc """
  Invoice status distribution - count and total amount per status.
  """
  @spec status_distribution(binary()) :: [map()]
  def status_distribution(user_id) do
    from(i in Invoice,
      where: i.user_id == ^user_id,
      group_by: i.status,
      select: %{
        status: i.status,
        count: count(i.id),
        total:
          coalesce(
            sum(
              coalesce(
                i.amount_krw,
                fragment("CASE WHEN ? = 'KRW' THEN ? ELSE 0 END", i.currency, i.amount)
              )
            ),
            0
          )
      }
    )
    |> Repo.all()
  end

  @doc """
  Invoice aging buckets for unpaid invoices (sent, overdue, partially_paid).
  Groups by days since due_date into 0-30, 31-60, 61-90, 90+ buckets.
  """
  @spec invoice_aging(binary()) :: map()
  def invoice_aging(user_id) do
    today = Date.utc_today()

    unpaid_invoices =
      from(i in Invoice,
        where: i.user_id == ^user_id,
        where: i.status in ~w(sent overdue partially_paid),
        where: not is_nil(i.due_date),
        select: %{
          # AMI-90: KRW-equivalent so aging buckets sum correctly across currencies.
          amount:
            coalesce(
              i.amount_krw,
              fragment("CASE WHEN ? = 'KRW' THEN ? ELSE 0 END", i.currency, i.amount)
            ),
          paid_amount: i.paid_amount,
          currency: i.currency,
          due_date: i.due_date
        }
      )
      |> Repo.all()

    default_buckets = %{
      "0-30" => %{count: 0, total: Decimal.new(0)},
      "31-60" => %{count: 0, total: Decimal.new(0)},
      "61-90" => %{count: 0, total: Decimal.new(0)},
      "90+" => %{count: 0, total: Decimal.new(0)}
    }

    Enum.reduce(unpaid_invoices, default_buckets, fn invoice, acc ->
      days_overdue = Date.diff(today, invoice.due_date)
      remaining = Decimal.sub(invoice.amount, invoice.paid_amount)
      bucket = aging_bucket(days_overdue)

      Map.update!(acc, bucket, fn current ->
        %{count: current.count + 1, total: Decimal.add(current.total, remaining)}
      end)
    end)
  end

  @doc """
  Cashflow forecast for the next N days.

  For each unpaid invoice, predicts payment date as due_date + client.avg_payment_days
  and groups by predicted date. Each bucket reports both the raw `expected_amount`
  (full outstanding) and a probability-adjusted `weighted_amount` (AMI-33), scaling
  the outstanding by each client's historical on-time collection rate. Clients with
  no payment history use a conservative default collection probability.
  """
  @spec cashflow_forecast(binary(), pos_integer()) :: [map()]
  def cashflow_forecast(user_id, days \\ 90) do
    today = Date.utc_today()
    horizon = Date.add(today, days)

    unpaid_invoices =
      from(i in Invoice,
        where: i.user_id == ^user_id,
        where: i.status in ~w(sent overdue partially_paid),
        join: c in Client,
        on: c.id == i.client_id,
        select: %{
          # AMI-90: KRW-equivalent so cashflow forecast sums correctly.
          amount:
            coalesce(
              i.amount_krw,
              fragment("CASE WHEN ? = 'KRW' THEN ? ELSE 0 END", i.currency, i.amount)
            ),
          paid_amount: i.paid_amount,
          currency: i.currency,
          due_date: i.due_date,
          avg_payment_days: c.avg_payment_days,
          client_id: c.id
        }
      )
      |> Repo.all()

    probabilities = collection_probabilities(unpaid_invoices)

    unpaid_invoices
    |> Enum.map(fn inv ->
      offset = inv.avg_payment_days || 0
      predicted_date = Date.add(inv.due_date || today, offset)
      remaining = Decimal.sub(inv.amount, inv.paid_amount)
      probability = Map.get(probabilities, inv.client_id, @default_collection_probability)
      weighted = Decimal.mult(remaining, probability)
      {predicted_date, remaining, weighted}
    end)
    |> Enum.filter(fn {date, _remaining, _weighted} ->
      Date.compare(date, horizon) != :gt
    end)
    |> Enum.group_by(fn {date, _, _} -> date end)
    |> Enum.map(fn {date, entries} ->
      %{
        date: date,
        expected_amount: sum_amounts(entries, fn {_, remaining, _} -> remaining end),
        weighted_amount: sum_amounts(entries, fn {_, _, weighted} -> weighted end),
        invoice_count: length(entries)
      }
    end)
    |> Enum.sort_by(& &1.date, Date)
  end

  @doc """
  AMI-51: per-currency breakdown of outstanding invoices for multi-currency
  portfolios. For each currency in use it returns the native total, the
  KRW-equivalent total, the FX rate used (1 unit → KRW), and whether the
  conversion succeeded (false when no FX rate is cached yet).

  Returns `%{rows: [...], total_krw: Decimal, multi_currency?: boolean}`.
  The `rows` are sorted with the largest KRW total first.
  """
  @spec currency_breakdown(binary()) :: %{
          rows: [map()],
          total_krw: Decimal.t(),
          multi_currency?: boolean()
        }
  def currency_breakdown(user_id) do
    rows =
      from(i in Invoice,
        where: i.user_id == ^user_id,
        where: i.status in ^@outstanding_statuses,
        group_by: i.currency,
        select: %{
          currency: i.currency,
          native_total: coalesce(sum(i.amount), 0),
          count: count(i.id)
        }
      )
      |> Repo.all()
      |> Enum.map(&convert_row/1)
      |> Enum.sort_by(& &1.krw_total, &(Decimal.compare(&1, &2) != :lt))

    total_krw = Enum.reduce(rows, Decimal.new(0), &Decimal.add(&2, &1.krw_total))

    %{
      rows: rows,
      total_krw: total_krw,
      multi_currency?: length(rows) > 1
    }
  end

  ## Private

  # AMI-33: per-client collection probability derived from historical on-time rate.
  defp collection_probabilities(invoices) do
    invoices
    |> Enum.map(& &1.client_id)
    |> Enum.uniq()
    |> Map.new(fn client_id ->
      probability =
        case Clients.on_time_rate(client_id) do
          rate when is_float(rate) and rate > 0.0 ->
            Decimal.div(Decimal.from_float(rate), Decimal.new(100))

          _ ->
            @default_collection_probability
        end

      {client_id, probability}
    end)
  end

  defp sum_amounts(entries, mapper) do
    entries
    |> Enum.map(mapper)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  # AMI-51: convert one currency bucket's native total to KRW using latest FX rate.
  defp convert_row(%{currency: currency, native_total: native, count: count}) do
    case FxRates.to_krw(native, currency) do
      {:ok, krw} ->
        %{
          currency: currency,
          native_total: native,
          krw_total: krw,
          rate: fx_rate_for(currency),
          count: count,
          converted?: true
        }

      {:error, :missing_rate} ->
        %{
          currency: currency,
          native_total: native,
          krw_total: Decimal.new(0),
          rate: nil,
          count: count,
          converted?: false
        }
    end
  end

  defp fx_rate_for("KRW"), do: Decimal.new(1)

  defp fx_rate_for(currency) do
    case FxRates.latest_rate(currency) do
      %{rate: rate} -> rate
      nil -> nil
    end
  end

  defp aging_bucket(days) when days <= 30, do: "0-30"
  defp aging_bucket(days) when days <= 60, do: "31-60"
  defp aging_bucket(days) when days <= 90, do: "61-90"
  defp aging_bucket(_days), do: "90+"

  defp generate_month_range(start_date, months) do
    Enum.map(0..(months - 1), fn offset ->
      start_date
      |> Date.shift(month: offset)
      |> Calendar.strftime("%Y-%m")
    end)
  end
end
