defmodule ElixirEcsLogger do
  @moduledoc """
  Module provides logging functionalities adhering to ECS (Elastic Common Schema) standards.
  It supports logging at various levels with structured data.
  """

  require Logger

  @debug "DEBUG"
  @info "INFO"
  @error "ERROR"
  @warning "WARNING"
  @critical "CRITICAL"

  @spec log_ecs(
          attrs ::
            %{
              error_code: String.t(),
              error_message: String.t(),
              level: String.t() | nil,
              internal_error_code: String.t() | nil,
              internal_error_message: String.t() | nil,
              additional_details: any() | nil,
              message_id: String.t() | nil,
              consumer: String.t() | nil
            }
        ) :: :ok | {:error, String.t()}

  @doc """
  Log an ECS log record with the provider information.
  """
  def log_ecs(attrs) when is_map(attrs) do
    with {:ok, exception} <- build_core_exception(attrs),
         log <- build_log_record(exception, attrs) do
      print_log_error(log)
      :ok
    else
      error -> error
    end
  end

  def log_ecs(_attrs) do
    message = "[ECS] log attributes must be provided as a map."
    Logger.error(message)
    {:error, message}
  end

  defp build_core_exception(attrs) do
    case CoreException.new(attrs) do
      {:ok, exception} -> {:ok, exception}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_log_record(%CoreException{} = core_exception, attrs) do
    LogRecord.build_log_record(core_exception, attrs)
  end

  defp print_log_error(%LogRecord{} = log_record) do
    json_log = Jason.encode!(log_record)

    case log_record.level do
      @debug -> Logger.debug(json_log)
      @info -> Logger.info(json_log)
      @warning -> Logger.warning(json_log)
      @error -> Logger.error(json_log)
      @critical -> Logger.critical(json_log)
    end
  end
end
