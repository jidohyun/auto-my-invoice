defmodule AutoMyInvoice.Teams do
  @moduledoc """
  Pro 플랜 팀 관리 Context.

  팀 생성, 이메일 초대, 멤버 역할(owner/member) 및 멤버 목록을 다룹니다.
  Pro 플랜 권한 확인은 호출 측(LiveView)에서 `Accounts.plan_allows?/2`로 수행합니다.
  """

  import Ecto.Query

  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.Accounts.{Team, TeamMembership, TeamNotifier, User}

  ## 팀 생성

  @spec create_team(User.t(), map()) :: {:ok, Team.t()} | {:error, Ecto.Changeset.t()}
  def create_team(%User{} = owner, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:team, Team.changeset(%Team{}, build_team_attrs(attrs, owner)))
    |> Ecto.Multi.insert(:owner_membership, fn %{team: team} ->
      now = DateTime.truncate(DateTime.utc_now(), :second)

      TeamMembership.changeset(%TeamMembership{}, %{
        team_id: team.id,
        user_id: owner.id,
        email: owner.email,
        role: "owner",
        status: "active",
        invited_at: now,
        accepted_at: now
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{team: team}} -> {:ok, team}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  defp build_team_attrs(attrs, owner) do
    attrs
    |> normalize_keys()
    |> Map.put("owner_id", owner.id)
  end

  ## 조회

  @spec get_team_for_owner(User.t()) :: Team.t() | nil
  def get_team_for_owner(%User{} = owner) do
    Repo.get_by(Team, owner_id: owner.id)
  end

  @spec list_members(Team.t()) :: [TeamMembership.t()]
  def list_members(%Team{} = team) do
    from(m in TeamMembership,
      where: m.team_id == ^team.id,
      order_by: [asc: m.inserted_at]
    )
    |> Repo.all()
  end

  ## 초대

  @spec invite_member(Team.t(), map()) ::
          {:ok, TeamMembership.t()} | {:error, Ecto.Changeset.t()}
  def invite_member(%Team{} = team, attrs) do
    attrs = normalize_keys(attrs)
    email = attrs |> Map.get("email", "") |> normalize_email()
    linked_user = Accounts.get_user_by_email(email)

    membership_attrs = %{
      team_id: team.id,
      user_id: linked_user && linked_user.id,
      email: email,
      role: "member",
      status: "pending",
      invited_at: DateTime.truncate(DateTime.utc_now(), :second)
    }

    %TeamMembership{}
    |> TeamMembership.changeset(membership_attrs)
    |> Repo.insert()
    |> case do
      {:ok, membership} ->
        TeamNotifier.deliver_invitation(membership.email, team.name)
        {:ok, membership}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  ## 멤버 제거

  @spec remove_member(Team.t(), binary()) ::
          {:ok, TeamMembership.t()} | {:error, :not_found | :cannot_remove_owner}
  def remove_member(%Team{} = team, membership_id) do
    case Repo.get_by(TeamMembership, id: membership_id, team_id: team.id) do
      nil -> {:error, :not_found}
      %TeamMembership{role: "owner"} -> {:error, :cannot_remove_owner}
      %TeamMembership{} = membership -> Repo.delete(membership)
    end
  end

  ## Private

  defp normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  defp normalize_email(_), do: ""

  defp normalize_keys(attrs) do
    Map.new(attrs, fn {k, v} -> {to_string(k), v} end)
  end
end
