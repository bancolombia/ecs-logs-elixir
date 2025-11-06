defmodule CoreException do
  @moduledoc """
  Module contains the core information of the exception
  This module provides controlled creation with validation and error logging.
  """

  require Logger

  @debug "DEBUG"
  @info "INFO"
  @error "ERROR"
  @warning "WARNING"
  @critical "CRITICAL"
  @level_list [@debug, @info, @error, @warning, @critical]

  @required_fields [:error_code, :error_message]
  @optional_fields [:level, :internal_error_code, :internal_error_message, :additional_details]
  @all_fields @required_fields ++ @optional_fields

  defstruct [
    :level,
    :error_code,
    :error_message,
    :internal_error_code,
    :internal_error_message,
    :additional_details
  ]

  @type t :: %__MODULE__{
          level: String.t(),
          error_code: String.t(),
          error_message: String.t(),
          internal_error_code: String.t() | nil,
          internal_error_message: String.t() | nil,
          additional_details: any() | nil
        }

  def new(attrs) when is_map(attrs) do
    with :ok <- validate_required_fields(attrs),
         :ok <- validate_field_types(attrs),
         sanitized_attrs <- sanitize_and_default(attrs) do
      exception = struct(__MODULE__, sanitized_attrs)
      {:ok, exception}
    else
      {:error, reason} = error ->
        log_error("Failed to create CoreException: #{reason}")
        error
    end
  end

  def new(attrs) do
    reason = "Invalid input: expected map, got #{inspect(attrs)}"
    log_error("Failed to create CoreException: #{reason}")
    {:error, reason}
  end

  defp validate_required_fields(attrs) do
    missing_fields =
      @required_fields
      |> Enum.filter(fn field ->
        value = Map.get(attrs, field)
        is_nil(value) or value == ""
      end)

    case missing_fields do
      [] -> :ok
      fields -> {:error, "Missing required fields: #{inspect(fields)}"}
    end
  end

  defp validate_field_types(attrs) do
    with :ok <- validate_level(Map.get(attrs, :level)) do
      validate_string_fields(attrs)
    end
  end

  defp validate_level(nil), do: :ok
  defp validate_level(level) when level in @level_list, do: :ok

  defp validate_level(level),
    do: {:error, "Invalid level: #{inspect(level)}. Must be one of: #{inspect(@level_list)}"}

  defp validate_string_fields(attrs) do
    string_fields = [:error_code, :error_message, :internal_error_code, :internal_error_message]

    invalid_fields =
      string_fields
      |> Enum.filter(fn field ->
        value = Map.get(attrs, field)
        not is_nil(value) and not is_binary(value)
      end)

    case invalid_fields do
      [] -> :ok
      fields -> {:error, "Non-string values found in fields: #{inspect(fields)}"}
    end
  end

  defp sanitize_and_default(attrs) do
    attrs
    |> Map.put(:level, Map.get(attrs, :level, @error))
    |> Map.put(
      :additional_details,
      process_additional_details(Map.get(attrs, :additional_details))
    )
    |> Map.take(@all_fields)
    |> Enum.into(%{})
  end

  defp process_additional_details(nil), do: nil

  defp process_additional_details(%__struct__{} = details),
    do: Map.from_struct(details)

  defp process_additional_details(details) when is_map(details),
    do: details

  defp process_additional_details(details) do
    inspect(details)
  end

  defp log_error(message) do
    Logger.error("[ECS] #{message}")
  end
end
