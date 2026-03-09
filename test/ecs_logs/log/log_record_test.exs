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
        additional_details: %{detail: "info"},
        additional_info: %{uri: "/signup", responseCode: 409}
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
               additionalInfo: %{uri: "/signup", responseCode: 409},
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
      exception = %CoreException{level: "ERROR", error_message: "message", additional_info: %{}}

      assert %{
               error: %LogRecord.Error{
                 type: "PENDIENTE IMPLEMENTACION",
                 description: "PENDIENTE IMPLEMENTACION"
               }
             } = LogRecord.build_log_record(exception, %{})
    end

    test "should omit error block for non-error levels" do
      exception = %CoreException{level: "INFO", additional_info: %{uri: "/signin", responseCode: 200}}
      assert %LogRecord{error: nil} = LogRecord.build_log_record(exception, %{})
    end

    test "json encoder keeps error when present and removes when nil" do
      with_error = %LogRecord{level: "ERROR", error: %LogRecord.Error{type: "ER-1", message: "m", description: "d"}}
      without_error = %LogRecord{level: "INFO", error: nil}

      assert Jason.encode!(with_error) =~ "\"error\""
      refute Jason.encode!(without_error) =~ "\"error\""
    end
  end
end
