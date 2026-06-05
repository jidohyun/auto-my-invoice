defmodule AutoMyInvoice.ApiKeysTest do
  use AutoMyInvoice.DataCase

  alias AutoMyInvoice.ApiKeys
  alias AutoMyInvoice.Accounts

  defp create_user(attrs \\ %{}) do
    email = "user#{System.unique_integer([:positive])}@test.com"

    {:ok, user} =
      Accounts.register_user(%{
        email: Map.get(attrs, :email, email),
        password: "ValidPassword123!"
      })

    user
  end

  describe "generate_api_key/2" do
    test "returns the raw key once and persists only the hash" do
      user = create_user()

      assert {:ok, %{api_key: api_key, raw_key: raw_key}} =
               ApiKeys.generate_api_key(user, %{"name" => "CI token"})

      assert is_binary(raw_key)
      assert String.starts_with?(raw_key, "ami_")
      assert api_key.name == "CI token"
      assert api_key.prefix == String.slice(raw_key, 0, 8)
      assert api_key.hashed_key != raw_key
      assert api_key.revoked_at == nil
    end

    test "generated keys are unique" do
      user = create_user()
      {:ok, %{raw_key: a}} = ApiKeys.generate_api_key(user, %{"name" => "a"})
      {:ok, %{raw_key: b}} = ApiKeys.generate_api_key(user, %{"name" => "b"})
      assert a != b
    end

    test "validates the name" do
      user = create_user()
      assert {:error, changeset} = ApiKeys.generate_api_key(user, %{"name" => ""})
      assert %{name: _} = errors_on(changeset)
    end
  end

  describe "list_api_keys/1" do
    test "lists only active (non-revoked) keys for the user" do
      user = create_user()
      other = create_user()

      {:ok, %{api_key: k1}} = ApiKeys.generate_api_key(user, %{"name" => "k1"})
      {:ok, %{api_key: k2}} = ApiKeys.generate_api_key(user, %{"name" => "k2"})
      {:ok, %{api_key: _}} = ApiKeys.generate_api_key(other, %{"name" => "other"})

      {:ok, _} = ApiKeys.revoke_api_key(user, k2.id)

      ids = ApiKeys.list_api_keys(user) |> Enum.map(& &1.id)
      assert k1.id in ids
      refute k2.id in ids
      assert length(ids) == 1
    end
  end

  describe "revoke_api_key/2" do
    test "marks the key as revoked" do
      user = create_user()
      {:ok, %{api_key: key}} = ApiKeys.generate_api_key(user, %{"name" => "k"})

      assert {:ok, revoked} = ApiKeys.revoke_api_key(user, key.id)
      assert revoked.revoked_at != nil
    end

    test "cannot revoke another user's key" do
      user = create_user()
      other = create_user()
      {:ok, %{api_key: key}} = ApiKeys.generate_api_key(other, %{"name" => "k"})

      assert {:error, :not_found} = ApiKeys.revoke_api_key(user, key.id)
    end
  end

  describe "authenticate/1" do
    test "returns the user for a valid raw key and updates last_used_at" do
      user = create_user()
      {:ok, %{raw_key: raw_key}} = ApiKeys.generate_api_key(user, %{"name" => "k"})

      assert {:ok, found} = ApiKeys.authenticate(raw_key)
      assert found.id == user.id
    end

    test "returns error for an unknown key" do
      assert {:error, :invalid} = ApiKeys.authenticate("ami_nonexistent")
    end

    test "returns error for a revoked key" do
      user = create_user()
      {:ok, %{api_key: key, raw_key: raw_key}} = ApiKeys.generate_api_key(user, %{"name" => "k"})
      {:ok, _} = ApiKeys.revoke_api_key(user, key.id)

      assert {:error, :invalid} = ApiKeys.authenticate(raw_key)
    end
  end
end
