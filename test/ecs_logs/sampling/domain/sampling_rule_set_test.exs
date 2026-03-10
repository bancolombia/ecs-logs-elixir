defmodule SamplingRuleSetTest do
  use ExUnit.Case

  describe "struct API" do
    test "builds and fetches 20x and 40x rules" do
      ruleset =
        SamplingRuleSet.empty()
        |> SamplingRuleSet.put_20x_rule("/signin|200", 2, 1)
        |> SamplingRuleSet.put_40x_rule("/signup|ER-409", 1, 3)

      assert {:ok, %{show_count: 2, skip_count: 1, cycle: 3}} =
               SamplingRuleSet.fetch_20x_rule(ruleset, "/signin|200")

      assert {:ok, %{show_count: 1, skip_count: 3, cycle: 4}} =
               SamplingRuleSet.fetch_40x_rule(ruleset, "/signup|ER-409")
    end

    test "returns :error for missing keys" do
      ruleset = SamplingRuleSet.empty()

      assert :error = SamplingRuleSet.fetch_20x_rule(ruleset, "missing")
      assert :error = SamplingRuleSet.fetch_40x_rule(ruleset, "missing")
    end
  end

  describe "parsing API" do
    test "parses and expands valid rules" do
      rules20x_json =
        ~s([{"uri":"/signin","responseCode":"200","showCount":2,"skipCount":1}])

      rules40x_json =
        ~s([{"uri":"/signup","responseCode":"409","showCount":1,"skipCount":3,"errorCodes":"ER-409|ER-400"}])

      assert {:ok, rules20x} = SamplingRuleSet.parse_rules(rules20x_json, :rules20x)
      assert {:ok, rules40x} = SamplingRuleSet.parse_rules(rules40x_json, :rules40x)
      assert {:ok, ruleset} = SamplingRuleSet.build_ruleset(rules20x, rules40x)

      assert {:ok, _} = SamplingRuleSet.fetch_20x_rule(ruleset, "/signin|200")
      assert {:ok, _} = SamplingRuleSet.fetch_40x_rule(ruleset, "/signup|ER-409")
      assert {:ok, _} = SamplingRuleSet.fetch_40x_rule(ruleset, "/signup|ER-400")
    end

    test "returns [] for nil or empty json" do
      assert {:ok, []} = SamplingRuleSet.parse_rules(nil, :rules20x)
      assert {:ok, []} = SamplingRuleSet.parse_rules("", :rules40x)
    end

    test "returns descriptive errors for invalid inputs" do
      cases = [
        {"[", :rules20x, "Invalid JSON"},
        {%{}, :rules20x, "must be a JSON string"},
        {"{}", :rules20x, "must decode into an array"},
        {"[123]", :rules20x, "must be an object"},
        {~s([{"uri":"","responseCode":"200","showCount":1,"skipCount":0}]), :rules20x,
         "invalid uri"},
        {~s([{"uri":"/x","responseCode":"","showCount":1,"skipCount":0}]), :rules20x,
         "invalid responseCode"},
        {~s([{"uri":"/x","responseCode":"200","showCount":-1,"skipCount":0}]), :rules20x,
         "invalid showCount"},
        {~s([{"uri":"/x","responseCode":"200","showCount":1,"skipCount":-1}]), :rules20x,
         "invalid skipCount"},
        {~s([{"uri":"/x","responseCode":"200","showCount":0,"skipCount":0}]), :rules20x,
         "invalid cycle"},
        {~s([{"uri":"/x","responseCode":"401","showCount":1,"skipCount":0}]), :rules20x,
         "rules20x"},
        {~s([{"uri":"/x","responseCode":"200","showCount":1,"skipCount":0,"errorCodes":"ER-200"}]),
         :rules40x, "rules40x"},
        {~s([{"uri":"/x","responseCode":"200","showCount":1,"skipCount":0,"errorCodes":"ER-200"}]),
         :rules20x, "must not define errorCodes"},
        {~s([{"uri":"/x","responseCode":"400","showCount":1,"skipCount":0}]), :rules40x,
         "must define non-empty errorCodes"},
        {~s([{"uri":"/x","responseCode":"400","showCount":1,"skipCount":0,"errorCodes":"ER-400|ER@401"}]),
         :rules40x, "invalid errorCodes segments"}
      ]

      Enum.each(cases, fn {input, type, expected_reason} ->
        assert {:error, reason} = SamplingRuleSet.parse_rules(input, type)
        assert reason =~ expected_reason
      end)
    end

    test "validates accepted optional/required errorCodes behavior" do
      empty_string_20x =
        ~s([{"uri":"/x","responseCode":"200","showCount":1,"skipCount":0,"errorCodes":""}])

      assert {:ok, [_]} = SamplingRuleSet.parse_rules(empty_string_20x, :rules20x)
    end
  end
end
