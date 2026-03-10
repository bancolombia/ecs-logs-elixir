defmodule SamplingHelper do
  @moduledoc """
  Helper module for determining whether a log record should be printed based on sampling rules.
  """

  def should_log?(attrs, %LogRecord{} = log_record) when is_map(attrs) do
    case SamplingConfig.fetch_ruleset() do
      {:ok, ruleset} -> do_should_log(attrs, log_record, ruleset)
      {:error, _reason} -> true
    end
  end

  def should_log?(_attrs, %LogRecord{}), do: true

  defp do_should_log(attrs, log_record, ruleset) do
    details = Map.get(attrs, :additional_info)
    uri = get_value(details, [:uri, "uri"])
    response_code = get_response_code(details)

    if invalid_uri_or_code?(uri, response_code) do
      true
    else
      case response_code_family(response_code) do
        :r20x -> should_log_20x(ruleset, uri, response_code)
        :r40x -> should_log_40x(ruleset, uri, error_type(log_record))
        :other -> true
      end
    end
  end

  defp error_type(%LogRecord{error: nil}), do: nil
  defp error_type(%LogRecord{error: %LogRecord.Error{type: type}}), do: type

  defp should_log_20x(ruleset, uri, response_code) do
    sample_by_key(ruleset, :rules20x, uri, response_code)
  end

  defp should_log_40x(ruleset, uri, error_type) do
    case derive_error_code(error_type) do
      nil -> true
      error_code -> sample_by_key(ruleset, :rules40x, uri, error_code)
    end
  end

  defp sample_by_key(ruleset, :rules20x, uri, code) do
    key = "#{uri}|#{code}"
    fetch_and_run(SamplingRuleSet.fetch_20x_rule(ruleset, key), key)
  end

  defp sample_by_key(ruleset, :rules40x, uri, code) do
    key = "#{uri}|#{code}"
    fetch_and_run(SamplingRuleSet.fetch_40x_rule(ruleset, key), key)
  end

  defp fetch_and_run({:ok, rule}, key),
    do: SamplingCounter.next_position(key, rule.cycle) < rule.show_count

  defp fetch_and_run(:error, _key), do: true

  def derive_error_code(nil), do: nil

  def derive_error_code(error_type) when is_binary(error_type) do
    parts = String.split(error_type, "-", trim: true)

    case parts do
      [first, second | _] -> "#{first}-#{second}"
      _ -> nil
    end
  end

  def derive_error_code(_), do: nil

  defp get_response_code(details) do
    value = get_value(details, [:response_code, "response_code", :responseCode, "responseCode"])

    cond do
      is_integer(value) -> Integer.to_string(value)
      is_binary(value) -> value
      true -> nil
    end
  end

  defp get_value(nil, _keys), do: nil

  defp get_value(details, keys) when is_map(details) do
    Enum.find_value(keys, fn key -> Map.get(details, key) end)
  end

  defp get_value(_details, _keys), do: nil

  defp invalid_uri_or_code?(uri, response_code) do
    not is_binary(uri) or uri == "" or not is_binary(response_code) or response_code == ""
  end

  defp response_code_family(code) do
    cond do
      String.starts_with?(code, "20") -> :r20x
      String.starts_with?(code, "40") -> :r40x
      true -> :other
    end
  end
end
