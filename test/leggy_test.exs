defmodule LeggyTest do
  use ExUnit.Case
  doctest Leggy

  setup_all do
    {:ok, _pid} = start_supervised(DemoRepo)
    :ok
  end

  describe "cast" do
    test "cast and validate data" do
      params = %{
        user: "r2d2",
        ttl: 5,
        valid?: true,
        requested_at: "2025-10-15T21:19:34Z"
      }

      assert {:ok, struct} = Leggy.Schema.cast(EmailSchema, params)

      assert struct.user == "r2d2"
      assert struct.ttl == 5
      assert struct.valid? == true
      assert %DateTime{} = struct.requested_at
      assert struct.__exchange__ == "exchange_test"
      assert struct.__queue__ == "queue_test"
    end

    test "cast fails if data is invalid" do
      params = %{
        user: "r2d2",
        ttl: "invalid",
        valid?: true,
        requested_at: "2025-10-15T21:19:34Z"
      }

      assert {:error, errors} = Leggy.Schema.cast(EmailSchema, params)
      assert errors[:ttl]
    end
  end

  describe "prepare" do
    test "create exchange, queue and bind them succesfully" do
      assert :ok = DemoRepo.prepare(EmailSchema)
    end
  end

  describe "publish and get" do
    test "publish and get messages" do
      params = %{
        user: "r2d2",
        ttl: 10,
        valid?: true,
        requested_at: "2025-10-15T21:19:34Z"
      }

      assert :ok == DemoRepo.prepare(EmailSchema)

      {:ok, msg} = DemoRepo.cast(EmailSchema, params)

      :ok = DemoRepo.publish(msg)

      {:ok, received} = DemoRepo.get(EmailSchema)

      assert received.user == "r2d2"
    end
  end
end
