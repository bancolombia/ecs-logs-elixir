defmodule SamplingCounterTest do
  use ExUnit.Case

  describe "counter store" do
    test "ensure_table! creates table and can be called repeatedly" do
      assert is_reference(SamplingCounter.ensure_table!())
      assert is_reference(SamplingCounter.ensure_table!())
    end

    test "next_position cycles based on cycle length" do
      SamplingCounter.reset!()

      positions = Enum.map(1..5, fn _ -> SamplingCounter.next_position("k", 2) end)
      assert positions == [0, 1, 0, 1, 0]
    end

    test "reset! clears table objects" do
      _ = SamplingCounter.next_position("k", 4)
      assert :ok = SamplingCounter.reset!()

      assert SamplingCounter.next_position("k", 4) == 0
    end
  end

  describe "genserver" do
    setup do
      Application.put_env(:ecs_logs_elixir, :sampling_source_app, :api_auth)
      Application.put_env(:ecs_logs_elixir, :sampling_source_key, :ecs_sampling)
      Application.put_env(:api_auth, :ecs_sampling, rules20XJson: "[]", rules40XJson: "[]")
      SamplingConfig.clear_cache()

      on_exit(fn ->
        if Process.whereis(SamplingCounter) do
          GenServer.stop(SamplingCounter)
        end

        Application.delete_env(:api_auth, :ecs_sampling)
        Application.delete_env(:ecs_logs_elixir, :sampling_source_app)
        Application.delete_env(:ecs_logs_elixir, :sampling_source_key)
        SamplingConfig.clear_cache()
      end)

      :ok
    end

    test "start_link starts named process and initializes dependencies" do
      started_pid =
        case SamplingCounter.start_link([]) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      assert Process.alive?(started_pid)
      assert Process.whereis(SamplingCounter) == started_pid

      assert is_reference(SamplingCounter.ensure_table!())
      assert {:ok, _} = SamplingConfig.fetch_ruleset()
    end
  end
end
