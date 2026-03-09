defmodule LogRecord do
  @moduledoc """
  Module represents a log record with structured information.
  """

  @pending_implementation "PENDIENTE IMPLEMENTACION"
  @error_level "ERROR"

  defmodule Error do
    @moduledoc false

    @derive Jason.Encoder
    defstruct [
      :type,
      :message,
      :description,
      :optionalInfo
    ]

    @type t :: %__MODULE__{
            type: String.t(),
            message: String.t(),
            description: String.t(),
            optionalInfo: map() | nil
          }
  end

  defstruct [
    :messageId,
    :date,
    :service,
    :consumer,
    :additionalInfo,
    :level,
    :error
  ]

  @type t :: %__MODULE__{
          messageId: String.t(),
          date: String.t(),
          service: String.t(),
          consumer: String.t(),
          additionalInfo: map(),
          level: String.t(),
          error: Error.t() | nil
        }

  defimpl Jason.Encoder do
    def encode(record, opts) do
      record
      |> Map.from_struct()
      |> then(fn map -> if is_nil(map.error), do: Map.delete(map, :error), else: map end)
      |> Jason.Encode.map(opts)
    end
  end

  def build_log_record(%CoreException{} = exception, attrs) do
    %__MODULE__{
      messageId: Map.get(attrs, :message_id, UUID.uuid4()),
      date: get_current_local_date(),
      service: get_service_name(),
      consumer: Map.get(attrs, :consumer),
      additionalInfo: exception.additional_info,
      level: exception.level,
      error: build_error(exception)
    }
  end

  defp build_error(%CoreException{level: @error_level} = exception) do
    %Error{
      type: exception.internal_error_code || @pending_implementation,
      message: exception.error_message,
      description: exception.internal_error_message || @pending_implementation,
      optionalInfo: exception.additional_details
    }
  end

  defp build_error(_exception), do: nil

  defp get_current_local_date do
    now = DateTime.utc_now() |> Timex.to_datetime("America/Bogota")
    Timex.format!(now, "{0D}/{0M}/{YYYY} {h24}:{m}:{s}{ss}")
  end

  defp get_service_name do
    case Application.fetch_env(:ecs_logs_elixir, :service_name) do
      {:ok, service_name} -> service_name
      :error -> "INDEFINIDO"
    end
  end
end
