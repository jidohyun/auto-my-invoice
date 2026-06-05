defmodule AutoMyInvoice.TeamsTest do
  use AutoMyInvoice.DataCase

  alias AutoMyInvoice.Teams
  alias AutoMyInvoice.Accounts

  import Swoosh.TestAssertions

  defp create_user(attrs \\ %{}) do
    email = "user#{System.unique_integer([:positive])}@test.com"

    {:ok, user} =
      Accounts.register_user(%{
        email: Map.get(attrs, :email, email),
        password: "ValidPassword123!"
      })

    user
  end

  describe "create_team/2" do
    test "creates a team owned by the user and an owner membership" do
      owner = create_user()

      assert {:ok, team} = Teams.create_team(owner, %{"name" => "Acme"})
      assert team.name == "Acme"
      assert team.owner_id == owner.id

      members = Teams.list_members(team)
      assert length(members) == 1
      [owner_membership] = members
      assert owner_membership.email == owner.email
      assert owner_membership.role == "owner"
      assert owner_membership.status == "active"
      assert owner_membership.user_id == owner.id
    end

    test "validates the team name" do
      owner = create_user()
      assert {:error, changeset} = Teams.create_team(owner, %{"name" => ""})
      assert %{name: _} = errors_on(changeset)
    end
  end

  describe "get_team_for_owner/1" do
    test "returns the team owned by the user" do
      owner = create_user()
      {:ok, team} = Teams.create_team(owner, %{"name" => "Acme"})

      assert %{id: id} = Teams.get_team_for_owner(owner)
      assert id == team.id
    end

    test "returns nil when the user has no team" do
      owner = create_user()
      assert Teams.get_team_for_owner(owner) == nil
    end
  end

  describe "invite_member/2" do
    test "invites a member by email and sends an invitation email" do
      owner = create_user()
      {:ok, team} = Teams.create_team(owner, %{"name" => "Acme"})

      assert {:ok, membership} = Teams.invite_member(team, %{"email" => "new@example.com"})
      assert membership.email == "new@example.com"
      assert membership.role == "member"
      assert membership.status == "pending"
      assert membership.invited_at != nil

      assert_email_sent(fn email ->
        assert {_, "new@example.com"} = hd(email.to)
        assert email.subject =~ "팀"
      end)
    end

    test "downcases and trims the invited email" do
      owner = create_user()
      {:ok, team} = Teams.create_team(owner, %{"name" => "Acme"})

      assert {:ok, membership} = Teams.invite_member(team, %{"email" => "  NEW@Example.com  "})
      assert membership.email == "new@example.com"
    end

    test "links an existing user to the membership" do
      owner = create_user()
      existing = create_user(%{email: "existing@example.com"})
      {:ok, team} = Teams.create_team(owner, %{"name" => "Acme"})

      assert {:ok, membership} = Teams.invite_member(team, %{"email" => "existing@example.com"})
      assert membership.user_id == existing.id
    end

    test "rejects duplicate invitations to the same email" do
      owner = create_user()
      {:ok, team} = Teams.create_team(owner, %{"name" => "Acme"})

      assert {:ok, _} = Teams.invite_member(team, %{"email" => "dup@example.com"})
      assert {:error, changeset} = Teams.invite_member(team, %{"email" => "dup@example.com"})
      assert %{team_id: ["이미 초대된 이메일입니다"]} = errors_on(changeset)
    end

    test "rejects invalid email" do
      owner = create_user()
      {:ok, team} = Teams.create_team(owner, %{"name" => "Acme"})

      assert {:error, changeset} = Teams.invite_member(team, %{"email" => "notanemail"})
      assert %{email: _} = errors_on(changeset)
    end
  end

  describe "list_members/1" do
    test "lists all memberships for a team ordered by insertion" do
      owner = create_user()
      {:ok, team} = Teams.create_team(owner, %{"name" => "Acme"})
      {:ok, _} = Teams.invite_member(team, %{"email" => "a@example.com"})
      {:ok, _} = Teams.invite_member(team, %{"email" => "b@example.com"})

      emails = Teams.list_members(team) |> Enum.map(& &1.email)
      assert owner.email in emails
      assert "a@example.com" in emails
      assert "b@example.com" in emails
      assert length(emails) == 3
    end
  end

  describe "remove_member/2" do
    test "removes a non-owner membership" do
      owner = create_user()
      {:ok, team} = Teams.create_team(owner, %{"name" => "Acme"})
      {:ok, membership} = Teams.invite_member(team, %{"email" => "remove@example.com"})

      assert {:ok, _} = Teams.remove_member(team, membership.id)
      assert length(Teams.list_members(team)) == 1
    end

    test "refuses to remove the owner membership" do
      owner = create_user()
      {:ok, team} = Teams.create_team(owner, %{"name" => "Acme"})
      [owner_membership] = Teams.list_members(team)

      assert {:error, :cannot_remove_owner} = Teams.remove_member(team, owner_membership.id)
      assert length(Teams.list_members(team)) == 1
    end

    test "returns error for a membership belonging to another team" do
      owner1 = create_user()
      owner2 = create_user()
      {:ok, team1} = Teams.create_team(owner1, %{"name" => "T1"})
      {:ok, team2} = Teams.create_team(owner2, %{"name" => "T2"})
      {:ok, membership} = Teams.invite_member(team2, %{"email" => "x@example.com"})

      assert {:error, :not_found} = Teams.remove_member(team1, membership.id)
    end
  end
end
