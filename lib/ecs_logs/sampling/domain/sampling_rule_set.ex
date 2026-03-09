defmodule SamplingRuleSet do
  @moduledoc """
  Represents the parsed sampling ruleset and provides parsing and validation
  of sampling rule definitions loaded from JSON configuration.
  """

  require Logger

  @error_code_segment_regex ~r/^[\w\-]+$/

  @type rule :: %{
          show_count: non_neg_integer(),
          skip_count: non_neg_integer(),
          cycle: pos_integer()
        }

  @type t :: %__MODULE__{
          rules20x: %{optional(String.t()) => rule()},
          rules40x: %{optional(String.t()) => rule()}
        }

  defstruct rules20x: %{}, rules40x: %{}

  # --- Struct API ---

  def empty, do: %__MODULE__{}

  def put_20x_rule(%__MODULE__{} = ruleset, key, show_count, skip_count),
    do: put_rule(ruleset, :rules20x, key, show_count, skip_count)

  def put_40x_rule(%__MODULE__{} = ruleset, key, show_count, skip_count),
    do: put_rule(ruleset, :rules40x, key, show_count, skip_count)

  def fetch_20x_rule(%__MODULE__{rules20x: rules}, key), do: fetch_rule(rules, key)

  def fetch_40x_rule(%__MODULE__{rules40x: rules}, key), do: fetch_rule(rules, key)

  defp fetch_rule(rules, key), do: Map.fetch(rules, key)

  defp put_rule(%__MODULE__{} = ruleset, bucket, key, show_count, skip_count) do
    rule = %{show_count: show_count, skip_count: skip_count, cycle: show_count + skip_count}
    Map.update!(ruleset, bucket, &Map.put(&1, key, rule))
  end

  # --- Parsing API (absorbed from SamplingRuleParser) ---

  def parse_rules(json, _rule_type) when json in [nil, ""], do: {:ok, []}

  def parse_rules(json, rule_type) when is_binary(json) do
    with {:ok, decoded} <- Jason.decode(json),
         :ok <- validate_decoded(decoded, rule_type) do
      {:ok, decoded}
    else
      {:error, %Jason.DecodeError{} = error} ->
        log_rule_error("Invalid JSON for #{rule_type}: #{Exception.message(error)}")
        {:error, "Invalid JSON for #{rule_type}: #{Exception.message(error)}"}

      {:error, reason} ->
        log_rule_error(reason)
        {:error, reason}
    end
  end

  def parse_rules(_json, rule_type) do
    reason = "Rules for #{rule_type} must be a JSON string."
    log_rule_error(reason)
    {:error, reason}
  end

  def build_ruleset(rules20x, rules40x) do
    with {:ok, ruleset} <- expand_20x(rules20x) do
      expand_40x(ruleset, rules40x)
    end
  end

  # --- Validation (private) ---

  defp validate_decoded(decoded, _rule_type) when not is_list(decoded),
    do: {:error, "Rules JSON must decode into an array of objects."}

  defp validate_decoded(decoded, rule_type) do
    decoded
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {rule, index}, :ok ->
      case validate_rule(rule, rule_type, index) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_rule(rule, _rule_type, index) when not is_map(rule),
    do: {:error, "Rule ##{index} must be an object."}

  defp validate_rule(rule, rule_type, index) do
    with {:ok, _uri} <- validate_required_binary(rule, "uri", index),
         {:ok, response_code} <- validate_required_binary(rule, "responseCode", index),
         {:ok, show_count} <- validate_non_negative_integer(rule, "showCount", index),
         {:ok, skip_count} <- validate_non_negative_integer(rule, "skipCount", index),
         :ok <- validate_cycle(show_count, skip_count, index),
         :ok <- validate_response_code_prefix(response_code, rule_type, index) do
      validate_error_codes(rule, rule_type, index)
    end
  end

  defp validate_required_binary(rule, key, index) do
    value = Map.get(rule, key)

    if is_binary(value) and value != "" do
      {:ok, value}
    else
      {:error, "Rule ##{index} has invalid #{key}: expected non-empty string."}
    end
  end

  defp validate_non_negative_integer(rule, key, index) do
    value = Map.get(rule, key)

    if is_integer(value) and value >= 0 do
      {:ok, value}
    else
      {:error, "Rule ##{index} has invalid #{key}: expected non-negative integer."}
    end
  end

  defp validate_cycle(show_count, skip_count, index) do
    if show_count + skip_count > 0 do
      :ok
    else
      {:error,
       "Rule ##{index} has invalid cycle: showCount + skipCount must be greater than zero."}
    end
  end

  defp validate_response_code_prefix(response_code, rule_type, index) do
    expected_prefix = if rule_type == :rules20x, do: "20", else: "40"

    if String.starts_with?(response_code, expected_prefix) do
      :ok
    else
      {:error,
       "Rule ##{index} for #{rule_type} must have responseCode starting with '#{expected_prefix}'."}
    end
  end

  defp validate_error_codes(rule, :rules20x, index) do
    case Map.get(rule, "errorCodes") do
      value when value in [nil, ""] -> :ok
      _ -> {:error, "Rule ##{index} for rules20x must not define errorCodes."}
    end
  end

  defp validate_error_codes(rule, :rules40x, index) do
    case Map.get(rule, "errorCodes") do
      value when is_binary(value) and value != "" -> validate_error_code_segments(value, index)
      _ -> {:error, "Rule ##{index} for rules40x must define non-empty errorCodes."}
    end
  end

  defp validate_error_code_segments(error_codes, index) do
    invalid =
      error_codes
      |> String.split("|", trim: true)
      |> Enum.filter(&(not Regex.match?(@error_code_segment_regex, &1)))

    case invalid do
      [] -> :ok
      _ -> {:error, "Rule ##{index} has invalid errorCodes segments: #{inspect(invalid)}"}
    end
  end

  defp log_rule_error(reason), do: Logger.error("[ECS] Invalid sampling rule: #{reason}")

  defp expand_20x(rules20x) do
    ruleset =
      Enum.reduce(rules20x, empty(), fn rule, acc ->
        key = "#{Map.fetch!(rule, "uri")}|#{Map.fetch!(rule, "responseCode")}"
        put_20x_rule(acc, key, Map.fetch!(rule, "showCount"), Map.fetch!(rule, "skipCount"))
      end)

    {:ok, ruleset}
  end

  defp expand_40x(ruleset, rules40x) do
    result =
      Enum.reduce(rules40x, ruleset, fn rule, acc ->
        uri = Map.fetch!(rule, "uri")
        show_count = Map.fetch!(rule, "showCount")
        skip_count = Map.fetch!(rule, "skipCount")

        rule
        |> Map.fetch!("errorCodes")
        |> String.split("|", trim: true)
        |> Enum.reduce(acc, fn error_code, inner_acc ->
          put_40x_rule(inner_acc, "#{uri}|#{error_code}", show_count, skip_count)
        end)
      end)

    {:ok, result}
  end
end
