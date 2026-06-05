defmodule AutoMyInvoice.NotificationsTest do
  # async: false — push_to_user tests swap the global dispatcher via Application env.
  use AutoMyInvoice.DataCase, async: false

  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.Notifications
  alias AutoMyInvoice.Notifications.Device

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "dev-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  describe "register_device/2" do
    test "creates a device with last_seen_at set" do
      user = create_user()

      assert {:ok, device} =
               Notifications.register_device(user.id, %{"token" => "abc", "platform" => "android"})

      assert device.user_id == user.id
      assert device.token == "abc"
      assert device.platform == "android"
      refute is_nil(device.last_seen_at)
    end

    test "accepts atom keys too" do
      user = create_user()

      assert {:ok, device} =
               Notifications.register_device(user.id, %{token: "z1", platform: "ios"})

      assert device.platform == "ios"
    end

    test "upserts by token (same user re-register updates last_seen_at)" do
      user = create_user()

      {:ok, first} =
        Notifications.register_device(user.id, %{"token" => "dup", "platform" => "android"})

      {:ok, second} =
        Notifications.register_device(user.id, %{"token" => "dup", "platform" => "ios"})

      assert first.id == second.id
      assert second.platform == "ios"
      assert Repo.aggregate(Device, :count) == 1
    end

    test "upsert reassigns token to a new owner" do
      user_a = create_user()
      user_b = create_user()

      {:ok, _} =
        Notifications.register_device(user_a.id, %{"token" => "shared", "platform" => "android"})

      {:ok, reassigned} =
        Notifications.register_device(user_b.id, %{"token" => "shared", "platform" => "android"})

      assert reassigned.user_id == user_b.id
      assert Notifications.list_user_devices(user_a.id) == []
    end

    test "rejects invalid platform" do
      user = create_user()

      assert {:error, changeset} =
               Notifications.register_device(user.id, %{"token" => "x", "platform" => "windows"})

      assert %{platform: _} = errors_on(changeset)
    end

    test "rejects missing token" do
      user = create_user()
      assert {:error, changeset} = Notifications.register_device(user.id, %{"platform" => "ios"})
      assert %{token: _} = errors_on(changeset)
    end
  end

  describe "list_user_devices/1" do
    test "returns only the user's devices" do
      user = create_user()
      other = create_user()

      {:ok, _} =
        Notifications.register_device(user.id, %{"token" => "u1", "platform" => "android"})

      {:ok, _} = Notifications.register_device(user.id, %{"token" => "u2", "platform" => "ios"})
      {:ok, _} = Notifications.register_device(other.id, %{"token" => "o1", "platform" => "ios"})

      assert length(Notifications.list_user_devices(user.id)) == 2
      assert length(Notifications.list_user_devices(other.id)) == 1
    end
  end

  describe "unregister_device/2" do
    test "deletes the matching token" do
      user = create_user()

      {:ok, _} =
        Notifications.register_device(user.id, %{"token" => "rm", "platform" => "android"})

      assert {:ok, _} = Notifications.unregister_device(user.id, "rm")
      assert Notifications.list_user_devices(user.id) == []
    end

    test "returns not_found for unknown token" do
      user = create_user()
      assert {:error, :not_found} = Notifications.unregister_device(user.id, "nope")
    end

    test "does not delete another user's token" do
      user = create_user()
      other = create_user()
      {:ok, _} = Notifications.register_device(other.id, %{"token" => "x", "platform" => "ios"})

      assert {:error, :not_found} = Notifications.unregister_device(user.id, "x")
      assert length(Notifications.list_user_devices(other.id)) == 1
    end
  end

  describe "delete_stale_devices/1" do
    test "removes devices older than the cutoff" do
      user = create_user()

      {:ok, fresh} =
        Notifications.register_device(user.id, %{"token" => "f", "platform" => "ios"})

      {:ok, old} =
        Notifications.register_device(user.id, %{"token" => "o", "platform" => "android"})

      stale_time = DateTime.add(DateTime.utc_now(), -100 * 86_400, :second)

      old
      |> Ecto.Changeset.change(last_seen_at: DateTime.truncate(stale_time, :second))
      |> Repo.update!()

      assert {1, _} = Notifications.delete_stale_devices(90)
      tokens = Notifications.list_user_devices(user.id) |> Enum.map(& &1.token)
      assert tokens == [fresh.token]
    end
  end

  describe "push_to_user/2" do
    test "fans out to every device via the configured dispatcher" do
      user = create_user()

      {:ok, _} =
        Notifications.register_device(user.id, %{"token" => "p1", "platform" => "android"})

      {:ok, _} = Notifications.register_device(user.id, %{"token" => "p2", "platform" => "ios"})

      test_pid = self()

      Application.put_env(:auto_my_invoice, Notifications,
        dispatcher: __MODULE__.RecordingDispatcher
      )

      Application.put_env(:auto_my_invoice, :test_push_sink, test_pid)
      on_exit(fn -> Application.delete_env(:auto_my_invoice, Notifications) end)

      assert {:ok, 2} =
               Notifications.push_to_user(user.id, %{title: "T", body: "B"})

      assert_received {:pushed, "p1"}
      assert_received {:pushed, "p2"}
    end

    test "individual dispatcher failure does not abort the fan-out" do
      user = create_user()

      {:ok, _} =
        Notifications.register_device(user.id, %{"token" => "ok", "platform" => "android"})

      {:ok, _} = Notifications.register_device(user.id, %{"token" => "fail", "platform" => "ios"})

      Application.put_env(:auto_my_invoice, Notifications, dispatcher: __MODULE__.FlakyDispatcher)

      on_exit(fn -> Application.delete_env(:auto_my_invoice, Notifications) end)

      assert {:ok, 1} = Notifications.push_to_user(user.id, %{title: "T", body: "B"})
    end

    test "returns {:ok, 0} when user has no devices" do
      user = create_user()
      assert {:ok, 0} = Notifications.push_to_user(user.id, %{title: "T", body: "B"})
    end
  end

  defmodule RecordingDispatcher do
    @behaviour AutoMyInvoice.Notifications.PushDispatcher

    @impl true
    def deliver(device, _payload) do
      pid = Application.get_env(:auto_my_invoice, :test_push_sink)
      if pid, do: send(pid, {:pushed, device.token})
      {:ok, %{receipt: "rec"}}
    end
  end

  defmodule FlakyDispatcher do
    @behaviour AutoMyInvoice.Notifications.PushDispatcher

    @impl true
    def deliver(%{token: "fail"}, _payload), do: {:error, :boom}
    def deliver(_device, _payload), do: {:ok, %{receipt: "rec"}}
  end
end
