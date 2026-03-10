# Elixir ECS Library

A comprehensive Elixir library that enables structured logging in ECS (Elastic Common Schema) format, providing standardized log output for better observability and monitoring in Elixir applications.

## Installation

Add `ecs_logs_elixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecs_logs_elixir, , "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Configuration

### Service Configuration

Configure your service name, sampling_source_app, and sampling_source_key in `config/config.exs`:

```elixir
config :ecs_logs_elixir,
  service_name: "my_application",
  sampling_source_app: :my_application,
  sampling_source_key: :ecs_sampling
```

- `service_name`: name of the service reported in the ECS payload. If not defined, the default value is `"INDEFINIDO"`.
- `sampling_source_app`: name of the application where the sampling configuration is stored. Default: `:ecs_logs_elixir`.
- `sampling_source_key`: configuration key used to read sampling rules. Default: `:ecs_sampling`.

## Sampling

It allows you to reduce the number of ECS logs written for selected requests instead of logging every matching event. Sampling rules are loaded from the application defined in `sampling_source_app` and the key defined in `sampling_source_key`.

Each sampling rule contains:

- `uri`: endpoint path to match.
- `responseCode`: HTTP response code used to classify the rule.
- `showCount`: number of matching logs to print.
- `skipCount`: number of matching logs to skip.
- `errorCodes`: pipe-separated error codes used only for `40X` rules.

### Sampling Configuration

In environment-specific files such as `config/dev.exs`, `config/test.exs`, and `config/pdn.exs`, define the sampling rules under the application and key configured by `sampling_source_app` and `sampling_source_key`.

Minimal structure:

```elixir
# sampling
config :my_application, :ecs_sampling,
  rules20XJson: "[{\"uri\":\"/signin\",\"responseCode\":\"200\",\"showCount\":1,\"skipCount\":1}]",
  rules40XJson: "[{\"uri\":\"/signin\",\"responseCode\":\"401\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-401\"},{\"uri\":\"/signup\",\"responseCode\":\"409\",\"showCount\":1,\"skipCount\":3,\"errorCodes\":\"ER-409\"}]"
```

### `rules20XJson`

Use this variable to define sampling rules for endpoints that return `20X` HTTP status codes.

Valid JSON value:

```json
[
  {
    "uri": "/signin",
    "responseCode": "200",
    "showCount": 1,
    "skipCount": 1
  }
]
```

This rule means that for `/signin` with HTTP `200`, the library prints `1` log and skips `1` log. In practice, matching requests are logged 50% of the time.

How it must look inside Elixir config:

```elixir
rules20XJson: "[{\"uri\":\"/signin\",\"responseCode\":\"200\",\"showCount\":1,\"skipCount\":1}]"
```

You can also use an empty string or an empty JSON array if you do not want sampling rules for `20X` responses.

### `rules40XJson`

Use this variable to define sampling rules for endpoints that return `40X` HTTP status codes.

Valid JSON value:

```json
[
  {
    "uri": "/signin",
    "responseCode": "401",
    "showCount": 1,
    "skipCount": 1,
    "errorCodes": "ER-401"
  },
  {
    "uri": "/signup",
    "responseCode": "409",
    "showCount": 1,
    "skipCount": 3,
    "errorCodes": "ER-409"
  },
  {
    "uri": "/signup",
    "responseCode": "400",
    "showCount": 1,
    "skipCount": 1,
    "errorCodes": "ER-400"
  },
  {
    "uri": "/signin",
    "responseCode": "404",
    "showCount": 1,
    "skipCount": 1,
    "errorCodes": "ER-404"
  }
]
```

These rules define sampling for `40X` responses using the derived error code. For example, `/signup` with derived error code `ER-409` prints `1` log and skips `3`, so matching requests are logged 25% of the time.

How it must look inside Elixir config:

```elixir
rules40XJson: "[{\"uri\":\"/signin\",\"responseCode\":\"401\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-401\"},{\"uri\":\"/signup\",\"responseCode\":\"409\",\"showCount\":1,\"skipCount\":3,\"errorCodes\":\"ER-409\"},{\"uri\":\"/signup\",\"responseCode\":\"400\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-400\"},{\"uri\":\"/signin\",\"responseCode\":\"404\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-404\"}]"
```

You can also use an empty string or an empty JSON array if you do not want sampling rules for `40X` responses.

Because both values are JSON arrays stored as strings, double quotes must be escaped inside Elixir config.

### Sampling Runtime Behavior

For `20X` responses:

- Rules are matched with the key `"#{uri}|#{responseCode}"`.
- `errorCodes` must not be configured. If present, it must be empty.

For `40X` responses:

- Rules are matched with the key `"#{uri}|#{derived_error_code}"`.
- `errorCodes` is required and must contain one or more pipe-separated values.
- The derived error code is built from the first two segments of `internal_error_code`.
- Example: `"ER-409-01-01"` becomes `"ER-409"`.

General behavior:

- `cycle = showCount + skipCount`.
- A log is printed when the current counter position is lower than `showCount`.
- Counters rotate within the configured cycle for each rule key.
- If no matching rule is found, the log is printed.
- If sampling configuration is missing, invalid, or cannot be parsed, the log is printed.
- Any response not covered by a configured rule is logged normally.

### Sampling Validation Notes

- `rules20XJson` only accepts rules whose `responseCode` starts with `20`.
- `rules40XJson` only accepts rules whose `responseCode` starts with `40`.
- `showCount` and `skipCount` must be non-negative integers.
- `showCount + skipCount` must be greater than `0`.
- An empty string or an empty JSON array means no sampling rules are applied for that group.

## Usage

### Basic Logging

```elixir
# Simple error logging
ElixirEcsLogger.log_ecs(%{
  error_code: "USER_001",
  error_message: "User validation failed",
  additional_info: %{
    uri: "/users",
    responseCode: 400
  }
})

# Logging with additional details
ElixirEcsLogger.log_ecs(%{
  error_code: "DB_001",
  error_message: "Database connection timeout",
  level: "ERROR",
  internal_error_code: "CONN_TIMEOUT",
  internal_error_message: "Connection to database timed out after 30 seconds",
  additional_details: %{
    database: "users_db",
    timeout: 30000,
    retry_count: 3
  },
  message_id: "msg_12345",
  consumer: "user_service",
  additional_info: %{
    uri: "/users",
    responseCode: 500
  }
})
```

### Log Levels

The library supports the following log levels:

- `"DEBUG"`: detailed information for debugging.
- `"INFO"`: general information messages.
- `"WARNING"`: warning messages for potential issues.
- `"ERROR"`: error messages for handled exceptions.
- `"CRITICAL"`: critical errors that may cause application failure.

```elixir
# Debug level logging
ElixirEcsLogger.log_ecs(%{
  error_code: "DEBUG_001",
  error_message: "Processing user request",
  level: "DEBUG",
  additional_info: %{
    uri: "/users",
    responseCode: 200
  }
})

# Critical level logging
ElixirEcsLogger.log_ecs(%{
  error_code: "CRIT_001",
  error_message: "Database connection lost",
  level: "CRITICAL",
  internal_error_code: "DB-500-01",
  internal_error_message: "Primary database is unreachable",
  additional_info: %{
    uri: "/users",
    responseCode: 500
  }
})
```

### Full Example

```elixir
defmodule MyApp.UserService do
  def create_user(params) do
    case validate_user(params) do
      {:ok, user} ->
        ElixirEcsLogger.log_ecs(%{
          error_code: "USER_CREATED",
          error_message: "User successfully created",
          level: "INFO",
          message_id: generate_message_id(),
          consumer: "user_service",
          additional_details: %{user_id: user.id},
          additional_info: %{
            uri: "/users",
            responseCode: 201
          }
        })

        {:ok, user}

      {:error, reason} ->
        ElixirEcsLogger.log_ecs(%{
          error_code: "USER_VALIDATION_FAILED",
          error_message: "User validation failed",
          level: "ERROR",
          internal_error_code: "VALIDATION_ERROR",
          internal_error_message: inspect(reason),
          additional_details: %{params: params},
          message_id: generate_message_id(),
          consumer: "user_service",
          additional_info: %{
            uri: "/users",
            responseCode: 400
          }
        })

        {:error, reason}
    end
  end
end
```

## Application Integration

Add ECS logging in both your global response and error handlers.

### Success Handler

```elixir
require ElixirEcsLogger

log_success(response, conn, headers, request_body)

defp log_success(%{status: status, body: response_body}, conn, headers, request_body) do
  payload = build_ecs_payload(conn, status, headers, request_body, response_body)
  ElixirEcsLogger.log_ecs(payload)
end

defp build_ecs_payload(conn, status, headers, request_body, response_body) do
  %{
    error_code: "",
    error_message: "",
    level: "INFO",
    internal_error_code: "",
    internal_error_message: "",
    additional_details: "",
    message_id: Map.get(headers, "message_id", ""),
    consumer: nil,
    additional_info: build_additional_info(conn, status, headers, request_body, response_body)
  }
end

defp build_additional_info(conn, status, headers, body, response_body) do
  %{
    method: conn.method,
    uri: conn.request_path,
    headers: headers,
    requestBody: body,
    responseBody: response_body,
    responseResult: "OK",
    responseCode: status
  }
end
```

### Error Handler

```elixir
require ElixirEcsLogger

@status_descriptions %{
  400 => "Bad Request",
  401 => "Unauthorized",
  404 => "Not Found",
  409 => "Conflict",
  500 => "Internal Server Error"
}

log_error(exception_data, conn, headers, body)

defp log_error(exception_data, conn, headers, body) do
  payload = build_ecs_payload(exception_data, conn, headers, body)
  ElixirEcsLogger.log_ecs(payload)
end

defp build_ecs_payload(exception_data, conn, headers, body) do
  %{
    error_code: exception_data.code,
    error_message: exception_data.detail,
    level: "ERROR",
    internal_error_code: exception_data.log_code,
    internal_error_message: exception_data.log_message,
    additional_details: "",
    message_id: Map.get(headers, "message_id", ""),
    consumer: nil,
    additional_info: build_additional_info(conn, exception_data.status, headers, body)
  }
end

defp build_additional_info(conn, status, headers, body) do
  %{
    method: conn.method,
    uri: conn.request_path,
    headers: headers,
    requestBody: body,
    responseResult: status_description(status),
    responseCode: status
  }
end

defp status_description(status), do: Map.get(@status_descriptions, status, "Unknown Error")
```

## API Documentation

### ElixirEcsLogger.log_ecs/1

Logs a structured message in ECS format.

**Parameters:**
- `attrs` (map) - Logging attributes

**Required attributes:**
- `error_code` (string) - Unique error code identifier. Required for `ERROR`, `WARNING`, and `CRITICAL` levels.
- `error_message` (string) - Human-readable error message. Required for `ERROR`, `WARNING`, and `CRITICAL` levels.
- `additional_info` (map) - Contextual data included in the ECS payload. For sampling decisions, `additional_info.uri` and `additional_info.responseCode` are required.

**Optional attributes:**
- `level` (string) - Log level (defaults to "ERROR")
- `internal_error_code` (string) - Internal system error code
- `internal_error_message` (string) - Internal system error message
- `additional_details` (any) - Additional context information
- `message_id` (string) - Unique message identifier
- `consumer` (string) - Service or component that generated the log

**Returns:**
- `:ok` - Successfully logged
- `{:error, reason}` - Error occurred during logging

## Log Output Format

The library generates JSON logs with the following structure:

```json
{
  "messageId": "12345",
  "date": "29/10/2025 17:48:55.734000",
  "service": "my_application",
  "consumer": "user_service",
  "additionalInfo": {
    "uri": "/users",
    "responseCode": 400
  },
  "level": "ERROR",
  "error": {
    "type": "VALIDATION_ERROR",
    "message": "User validation failed",
    "description": "Email format is invalid",
    "optionalInfo": {
      "field": "email",
      "value": "invalid-email"
    }
  }
}
```

For non-error levels such as `INFO` and `DEBUG`, the `error` object is omitted from the final JSON payload.

## Development

### Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix coveralls.html
```

### Code Quality

```bash
# Run code formatter
mix format

# Run static analysis
mix credo

# Run dialyzer
mix dialyzer
```

## Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Add tests for new functionality.
5. Ensure tests and checks pass.
6. Open a Pull Request.

### Development Guidelines

- Follow Elixir naming conventions.
- Write tests for new behavior.
- Update documentation when the public API changes.
- Ensure code passes formatting and static analysis checks.
- Add typespecs for public functions where appropriate.
