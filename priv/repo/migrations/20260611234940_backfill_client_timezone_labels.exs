defmodule AutoMyInvoice.Repo.Migrations.BackfillClientTimezoneLabels do
  use Ecto.Migration

  # A prior version of the client form stored the *label* as the timezone value,
  # so rows hold strings like "Asia/Seoul (KST)" that are not valid IANA zones.
  # Strip the " (ABBR)" suffix so DateTime.from_naive/2 resolves them correctly.
  # Anything still unrecognized is normalized to "UTC".
  @valid ~w(
    UTC Asia/Seoul Asia/Tokyo America/New_York America/Los_Angeles
    America/Chicago Europe/London Europe/Paris Europe/Berlin Australia/Sydney
  )

  def up do
    # Remove the parenthetical abbreviation: "Asia/Seoul (KST)" -> "Asia/Seoul"
    execute("""
    UPDATE clients
    SET timezone = trim(split_part(timezone, ' (', 1))
    WHERE timezone LIKE '% (%)'
    """)

    # Anything still not in the known-good set falls back to UTC.
    valid_list = Enum.map_join(@valid, ", ", &"'#{&1}'")

    execute("""
    UPDATE clients
    SET timezone = 'UTC'
    WHERE timezone IS NULL OR timezone NOT IN (#{valid_list})
    """)
  end

  def down do
    # No-op: the original malformed values are not worth restoring.
    :ok
  end
end
