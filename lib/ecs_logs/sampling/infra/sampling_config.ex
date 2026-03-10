defmodule SamplingConfig do
  @moduledoc """
  Manages the loading and caching of sampling rules for ECS logs.
  This module retrieves sampling rules from the application configuration, parses them, and caches the results for efficient access during log processing.
  The sampling rules are expected to be defined in the application configuration under a specified key, and they should be provided in JSON format.
  The module ensures that the rules are loaded and parsed correctly, and it provides a mechanism to clear the cache when needed.
  The `fetch_ruleset/0` function is the primary entry point for retrieving the sampling ruleset.
  It checks the cache for existing rules and loads them from the configuration if they are not cached or if the configuration has changed.
  The `clear_cache/0` function allows for clearing the cached ruleset, forcing a reload on the next fetch.
  """

  require Logger

  @cache_key {__MODULE__, :ruleset_cache}

  def fetch_ruleset do
    source_app = Application.get_env(:ecs_logs_elixir, :sampling_source_app, :ecs_logs_elixir)
    source_key = Application.get_env(:ecs_logs_elixir, :sampling_source_key, :ecs_sampling)

    config = Application.get_env(source_app, source_key, [])
    rules20x_json = get_config_value(config, :rules20XJson)
    rules40x_json = get_config_value(config, :rules40XJson)

    fingerprint = {source_app, source_key, rules20x_json, rules40x_json}

    case :persistent_term.get(@cache_key, :empty) do
      {^fingerprint, result} ->
        result

      _ ->
        result = parse_ruleset(rules20x_json, rules40x_json)
        log_rules_loaded(result, source_app, source_key)
        :persistent_term.put(@cache_key, {fingerprint, result})
        result
    end
  end

  @spec clear_cache() :: :ok
  def clear_cache do
    :persistent_term.erase(@cache_key)
    :ok
  end

  defp parse_ruleset(rules20x_json, rules40x_json) do
    with {:ok, rules20x} <- SamplingRuleSet.parse_rules(rules20x_json, :rules20x),
         {:ok, rules40x} <- SamplingRuleSet.parse_rules(rules40x_json, :rules40x),
         {:ok, ruleset} <- SamplingRuleSet.build_ruleset(rules20x, rules40x) do
      {:ok, ruleset}
    else
      {:error, _reason} = error -> error
    end
  end

  defp get_config_value(config, key) when is_map(config) do
    Map.get(config, key)
  end

  defp get_config_value(config, key) when is_list(config) do
    Keyword.get(config, key)
  end

  defp get_config_value(_config, _key), do: nil

  defp log_rules_loaded({:ok, %SamplingRuleSet{} = ruleset}, source_app, source_key) do
    rules20x_count = map_size(ruleset.rules20x)
    rules40x_count = map_size(ruleset.rules40x)
    total_rules = rules20x_count + rules40x_count

    Logger.debug(
      "[ECS] Sampling rules loaded from #{inspect(source_app)}:#{inspect(source_key)} - " <>
        "20X=#{rules20x_count}, 40X=#{rules40x_count}, total=#{total_rules}"
    )
  end

  defp log_rules_loaded({:error, _reason}, _source_app, _source_key), do: :ok
end
