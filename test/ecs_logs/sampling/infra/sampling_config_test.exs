defmodule SamplingConfigTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  setup do
    Application.put_env(:ecs_logs_elixir, :sampling_source_app, :api_auth)
    Application.put_env(:ecs_logs_elixir, :sampling_source_key, :ecs_sampling)

    on_exit(fn ->
      Application.delete_env(:ecs_logs_elixir, :sampling_source_app)
      Application.delete_env(:ecs_logs_elixir, :sampling_source_key)
      Application.delete_env(:api_auth, :ecs_sampling)
      SamplingConfig.clear_cache()
    end)

    SamplingConfig.clear_cache()
    :ok
  end

  test "fetch_ruleset works with keyword config and caches" do
    Application.put_env(:api_auth, :ecs_sampling,
      rules20XJson:
        "[{\"uri\":\"/signin\",\"responseCode\":\"200\",\"showCount\":1,\"skipCount\":1}]",
      rules40XJson: "[]"
    )

    assert {:ok, ruleset_a} = SamplingConfig.fetch_ruleset()
    assert {:ok, ruleset_b} = SamplingConfig.fetch_ruleset()

    assert ruleset_a == ruleset_b
    assert map_size(ruleset_a.rules20x) == 1
  end

  test "fetch_ruleset works with map config and non map fallback" do
    Application.put_env(:api_auth, :ecs_sampling, %{
      rules20XJson: "[]",
      rules40XJson:
        "[{\"uri\":\"/signup\",\"responseCode\":\"409\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-409\"}]"
    })

    assert {:ok, ruleset_map} = SamplingConfig.fetch_ruleset()
    assert map_size(ruleset_map.rules40x) == 1

    SamplingConfig.clear_cache()
    Application.put_env(:api_auth, :ecs_sampling, 123)

    assert {:ok, ruleset_other} = SamplingConfig.fetch_ruleset()
    assert ruleset_other == SamplingRuleSet.empty()
  end

  test "logs error and returns {:error, reason} for invalid rules" do
    Application.put_env(:api_auth, :ecs_sampling,
      rules20XJson: "[",
      rules40XJson: "[]"
    )

    output =
      capture_log(fn ->
        assert {:error, reason} = SamplingConfig.fetch_ruleset()
        assert reason =~ "Invalid JSON"
      end)

    assert output =~ "Invalid sampling rule"
  end

  test "clear_cache clears persistent term entry" do
    Application.put_env(:api_auth, :ecs_sampling, rules20XJson: "[]", rules40XJson: "[]")

    assert {:ok, _} = SamplingConfig.fetch_ruleset()
    assert :ok = SamplingConfig.clear_cache()
    assert {:ok, _} = SamplingConfig.fetch_ruleset()
  end

  test "logs total rules when loaded" do
    Application.put_env(:api_auth, :ecs_sampling,
      rules20XJson:
        "[{\"uri\":\"/signin\",\"responseCode\":\"200\",\"showCount\":1,\"skipCount\":1}]",
      rules40XJson:
        "[{\"uri\":\"/signup\",\"responseCode\":\"409\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-409\"}]"
    )

    output = capture_log(fn -> assert {:ok, _} = SamplingConfig.fetch_ruleset() end)

    assert output =~ "Sampling rules loaded"
    assert output =~ "20X=1"
    assert output =~ "40X=1"
    assert output =~ "total=2"
  end
end
