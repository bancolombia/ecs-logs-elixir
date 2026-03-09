defmodule ElixirEcsLoggerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "log_ecs/1" do
    test "should return an error when params are not a map" do
      assert {:error, "[ECS] log attributes must be provided as a map."} =
               ElixirEcsLogger.log_ecs("invalid input")
    end

    test "should return an error with empty params" do
      assert {:error, _reason} = ElixirEcsLogger.log_ecs(%{})
    end

    test "should return ok with valid params" do
      attrs = %{
        error_code: "code",
        error_message: "message",
        additional_info: %{uri: "/signup", responseCode: 409}
      }

      assert :ok = ElixirEcsLogger.log_ecs(attrs)
    end

    test "should log successfully with valid params" do
      attrs = %{
        error_code: "code",
        error_message: "message",
        additional_info: %{uri: "/signup", responseCode: 409}
      }

      log_output =
        capture_log(fn ->
          ElixirEcsLogger.log_ecs(attrs)
        end)

      assert log_output =~ "message"
      assert log_output =~ "ERROR"
    end

    test "should log at different levels correctly" do
      levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]

      Enum.each(levels, fn level ->
        attrs = %{
          error_code: "CODE",
          error_message: "Message",
          level: level,
          additional_info: %{uri: "/test", responseCode: if(level == "INFO", do: 200, else: 409)}
        }

        log_output =
          capture_log(fn ->
            ElixirEcsLogger.log_ecs(attrs)
          end)

        assert log_output =~ level
      end)
    end
  end
end
