defmodule CoreExceptionTest do
  use ExUnit.Case

  defp info_payload(response_code \\ 409) do
    %{uri: "/x", responseCode: response_code}
  end

  describe "new/1" do
    test "should return an error when attrs are not a map" do
      assert {:error, _reason} = CoreException.new("invalid input")
    end

    test "should validate required fields for error levels" do
      cases = [
        {%{error_message: "message", additional_info: info_payload()},
         "Missing required fields: [:error_code]"},
        {%{error_code: "code", additional_info: info_payload()},
         "Missing required fields: [:error_message]"},
        {%{}, "Missing required fields: [:error_code, :error_message, :additional_info]"}
      ]

      Enum.each(cases, fn {attrs, expected_error} ->
        assert {:error, ^expected_error} = CoreException.new(attrs)
      end)
    end

    test "should return an error when level value is invalid" do
      attrs = %{
        error_code: "code",
        error_message: "message",
        additional_info: info_payload(),
        level: "invalid_level"
      }

      assert {:error, _reason} = CoreException.new(attrs)
    end

    test "should return an error when string fields are not string" do
      attrs = %{
        error_code: {},
        error_message: [],
        internal_error_code: 123,
        additional_info: info_payload()
      }

      assert {:error, _reason} = CoreException.new(attrs)
    end

    test "should create CoreException struct when all validations pass" do
      attrs = %{
        error_code: "code",
        error_message: "message",
        level: "ERROR",
        internal_error_code: "internal_code",
        internal_error_message: "internal_message",
        additional_details: %{detail: "info"},
        additional_info: info_payload()
      }

      assert {:ok, %CoreException{} = exception} = CoreException.new(attrs)
      assert exception.error_code == "code"
      assert exception.error_message == "message"
      assert exception.level == "ERROR"
      assert exception.internal_error_code == "internal_code"
      assert exception.internal_error_message == "internal_message"
      assert exception.additional_details == %{detail: "info"}
    end

    test "should create CoreException struct when all validations pass with minimal fields" do
      attrs = %{
        error_code: "code",
        error_message: "message",
        additional_info: info_payload()
      }

      assert {:ok, %CoreException{} = exception} = CoreException.new(attrs)
      assert exception.error_code == "code"
      assert exception.error_message == "message"
      assert exception.level == "ERROR"
      assert exception.internal_error_code == nil
      assert exception.internal_error_message == nil
      assert exception.additional_details == nil
    end

    test "should normalize additional_details variants" do
      cases = [
        {"Some string details", fn details -> assert details =~ "Some string details" end},
        {%LogRecord{}, fn details -> assert details == Map.from_struct(%LogRecord{}) end}
      ]

      Enum.each(cases, fn {additional_details, assertion} ->
        attrs = %{
          error_code: "code",
          error_message: "message",
          additional_details: additional_details,
          additional_info: info_payload()
        }

        assert {:ok, %CoreException{} = exception} = CoreException.new(attrs)
        assertion.(exception.additional_details)
      end)
    end

    test "should allow INFO level without required error fields" do
      attrs = %{
        level: "INFO",
        additional_info: info_payload(200)
      }

      assert {:ok, %CoreException{} = exception} = CoreException.new(attrs)
      assert exception.level == "INFO"
      assert exception.error_code == nil
      assert exception.error_message == nil
      assert exception.additional_details == nil
    end
  end
end
