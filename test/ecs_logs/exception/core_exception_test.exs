defmodule CoreExceptionTest do
  use ExUnit.Case

  describe "new/1" do
    test "should return an error when attrs are not a map" do
      assert {:error, _reason} = CoreException.new("invalid input")
    end

    test "should return an error when error code is missing" do
      attrs = %{
        error_message: "message"
      }

      assert {:error, "Missing required fields: [:error_code]"} == CoreException.new(attrs)
    end

    test "should return an error when error message is missing" do
      attrs = %{
        error_code: "code"
      }

      assert {:error, "Missing required fields: [:error_message]"} == CoreException.new(attrs)
    end

    test "should return an error when all required fields are missing" do
      assert {:error, "Missing required fields: [:error_code, :error_message]"} ==
               CoreException.new(%{})
    end

    test "should return an error when level value is invalid" do
      attrs = %{
        error_code: "code",
        error_message: "message",
        level: "invalid_level"
      }

      assert {:error, _reason} = CoreException.new(attrs)
    end

    test "should return an error when string fields are not string" do
      attrs = %{
        error_code: {},
        error_message: [],
        internal_error_code: 123
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
        additional_details: %{detail: "info"}
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
        error_message: "message"
      }

      assert {:ok, %CoreException{} = exception} = CoreException.new(attrs)
      assert exception.error_code == "code"
      assert exception.error_message == "message"
      assert exception.level == "ERROR"
      assert exception.internal_error_code == nil
      assert exception.internal_error_message == nil
      assert exception.additional_details == nil
    end

    test "should create CoreException struct when additional details are not a map" do
      attrs = %{
        error_code: "code",
        error_message: "message",
        additional_details: "Some string details"
      }

      assert {:ok, %CoreException{} = exception} = CoreException.new(attrs)
      assert exception.error_code == "code"
      assert exception.error_message == "message"
      assert exception.level == "ERROR"
      assert exception.additional_details =~ "Some string details"
    end

    test "should create CoreException struct when additional details are an struct" do
      attrs = %{
        error_code: "code",
        error_message: "message",
        additional_details: %LogRecord{}
      }

      assert {:ok, %CoreException{} = exception} = CoreException.new(attrs)
      assert exception.error_code == "code"
      assert exception.error_message == "message"
      assert exception.level == "ERROR"
      assert exception.additional_details == Map.from_struct(%LogRecord{})
    end
  end
end
