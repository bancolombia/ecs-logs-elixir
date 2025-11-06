defmodule LogRecordTest do
  use ExUnit.Case

  describe "build_log_record/2" do
    setup do
      on_exit(fn -> Application.delete_env(:ecs_logs_elixir, :service_name) end)
      :ok
    end

    test "should build a log record from a CoreException and attributes" do
      exception_attrs = %{
        error_code: "code",
        error_message: "message",
        level: "ERROR",
        internal_error_code: "internal_code",
        internal_error_message: "internal_message",
        additional_details: %{detail: "info"}
      }

      {:ok, exception} = CoreException.new(exception_attrs)

      log_attrs = %{
        message_id: "12345",
        consumer: "consumer"
      }

      assert %LogRecord{
               messageId: "12345",
               date: date,
               service: "INDEFINIDO",
               consumer: "consumer",
               additionalInfo: nil,
               level: "ERROR",
               error: %LogRecord.Error{
                 type: "internal_code",
                 message: "message",
                 description: "internal_message",
                 optionalInfo: %{detail: "info"}
               }
             } = LogRecord.build_log_record(exception, log_attrs)

      assert Regex.match?(~r/^\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}\.\d{6}$/, date)
    end

    test "should build a log record with service name" do
      Application.put_env(:ecs_logs_elixir, :service_name, "my_app")
      assert %LogRecord{service: "my_app"} = LogRecord.build_log_record(%CoreException{}, %{})
    end

    test "should build a log record with pending to implement fields" do
      assert %{
               error: %LogRecord.Error{
                 type: "PENDIENTE IMPLEMENTACION",
                 description: "PENDIENTE IMPLEMENTACION"
               }
             } = LogRecord.build_log_record(%CoreException{}, %{})
    end
  end
end
