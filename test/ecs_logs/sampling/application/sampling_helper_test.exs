defmodule SamplingHelperTest do
  use ExUnit.Case

  setup do
    Application.put_env(:ecs_logs_elixir, :sampling_source_app, :api_auth)
    Application.put_env(:ecs_logs_elixir, :sampling_source_key, :ecs_sampling)

    on_exit(fn ->
      Application.delete_env(:ecs_logs_elixir, :sampling_source_app)
      Application.delete_env(:ecs_logs_elixir, :sampling_source_key)
      Application.delete_env(:api_auth, :ecs_sampling)
      SamplingConfig.clear_cache()
      SamplingCounter.reset!()
    end)

    SamplingConfig.clear_cache()
    SamplingCounter.reset!()

    :ok
  end

  test "returns true for attrs format and load failures" do
    Application.put_env(:api_auth, :ecs_sampling, rules20XJson: "[]", rules40XJson: "[]")

    assert SamplingHelper.should_log?("invalid", %LogRecord{})

    assert SamplingHelper.should_log?(%{}, %LogRecord{
             error: %LogRecord.Error{type: "ER-409-01-01"}
           })

    Application.put_env(:api_auth, :ecs_sampling,
      rules20XJson: "[",
      rules40XJson: "[]"
    )

    attrs = %{additional_info: %{uri: "/signup", responseCode: 409}}

    assert SamplingHelper.should_log?(attrs, %LogRecord{
             error: %LogRecord.Error{type: "ER-409-01-01"}
           })
  end

  test "returns true for missing uri, response_code and unknown prefixes" do
    Application.put_env(:api_auth, :ecs_sampling, rules20XJson: "[]", rules40XJson: "[]")

    assert SamplingHelper.should_log?(%{additional_info: %{responseCode: 409}}, %LogRecord{
             error: %LogRecord.Error{type: "ER-409-01-01"}
           })

    assert SamplingHelper.should_log?(%{additional_info: %{uri: "/x"}}, %LogRecord{
             error: %LogRecord.Error{type: "ER-409-01-01"}
           })

    assert SamplingHelper.should_log?(%{additional_info: "invalid"}, %LogRecord{
             error: %LogRecord.Error{type: "ER-409-01-01"}
           })

    assert SamplingHelper.should_log?(
             %{additional_info: %{uri: "/x", responseCode: 500}},
             %LogRecord{error: %LogRecord.Error{type: "ER-500-01"}}
           )
  end

  test "returns true for 40x edge cases without derivable error code" do
    Application.put_env(:api_auth, :ecs_sampling,
      rules20XJson: "[]",
      rules40XJson:
        "[{\"uri\":\"/signup\",\"responseCode\":\"409\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-409\"}]"
    )

    attrs = %{additional_info: %{uri: "/signup", responseCode: "409"}}
    assert SamplingHelper.should_log?(attrs, %LogRecord{error: nil})

    attrs40 = %{additional_info: %{uri: "/signup", responseCode: 409}}
    assert SamplingHelper.should_log?(attrs40, %LogRecord{error: %LogRecord.Error{type: "ER"}})
  end

  test "applies 20x and 40x sampling rules and missing rule fallback" do
    Application.put_env(:api_auth, :ecs_sampling,
      rules20XJson:
        "[{\"uri\":\"/signin\",\"responseCode\":\"200\",\"showCount\":1,\"skipCount\":1}]",
      rules40XJson:
        "[{\"uri\":\"/signup\",\"responseCode\":\"409\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-409\"}]"
    )

    attrs20 = %{additional_info: %{uri: "/signin", response_code: 200}}

    decisions20 =
      Enum.map(1..4, fn _ ->
        SamplingHelper.should_log?(attrs20, %LogRecord{error: %LogRecord.Error{type: "ER-200-00"}})
      end)

    assert decisions20 == [true, false, true, false]

    attrs40 = %{additional_info: %{uri: "/signup", responseCode: "409"}}

    decisions40 =
      Enum.map(1..4, fn _ ->
        SamplingHelper.should_log?(attrs40, %LogRecord{
          error: %LogRecord.Error{type: "ER-409-01-01"}
        })
      end)

    assert decisions40 == [true, false, true, false]

    missing_rule_attrs = %{additional_info: %{uri: "/missing", responseCode: 409}}

    assert SamplingHelper.should_log?(missing_rule_attrs, %LogRecord{
             error: %LogRecord.Error{type: "ER-409-01-01"}
           })

    missing_rule_20x_attrs = %{additional_info: %{uri: "/missing", responseCode: 200}}

    assert SamplingHelper.should_log?(missing_rule_20x_attrs, %LogRecord{
             error: %LogRecord.Error{type: "ER-200-00"}
           })
  end

  test "derive_error_code/1 variants" do
    assert SamplingHelper.derive_error_code("ER-409-01-01") == "ER-409"
    assert SamplingHelper.derive_error_code("ER-409") == "ER-409"
    assert SamplingHelper.derive_error_code("ER") == nil
    assert SamplingHelper.derive_error_code(nil) == nil
    assert SamplingHelper.derive_error_code(123) == nil
  end
end
