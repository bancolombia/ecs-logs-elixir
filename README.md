# Elixir ECS Library

A comprehensive Elixir library that enables structured logging in ECS (Elastic Common Schema) format, providing standardized log output for better observability and monitoring in Elixir applications.

## Installation

Add `ecs_logs_elixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecs_logs_elixir, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Configuration

### Library Configuration (`:ecs_logs_elixir`)

In your host API, add this to `config/config.exs`:

```elixir
config :ecs_logs_elixir,
  service_name: "api_auth",
  sampling_source_app: :api_auth,
  sampling_source_key: :ecs_sampling
```

- `service_name`: ECS `service` field value. Default: `"INDEFINIDO"`.
- `sampling_source_app`: app where sampling config lives. Default: `:ecs_logs_elixir`.
- `sampling_source_key`: config key used to read sampling rules. Default: `:ecs_sampling`.

### Sampling Configuration In Host API

In `config/dev.exs`, `config/test.exs`, and `config/pdn.exs` add:

```elixir
# sampling
config :api_auth, :ecs_sampling,
  rules20XJson: "[{\"uri\":\"/signin\",\"responseCode\":\"200\",\"showCount\":1,\"skipCount\":1}]",
  rules40XJson: "[{\"uri\":\"/signin\",\"responseCode\":\"401\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-401\"},
                  {\"uri\":\"/signup\",\"responseCode\":\"409\",\"showCount\":1,\"skipCount\":3,\"errorCodes\":\"ER-409\"},
                  {\"uri\":\"/signup\",\"responseCode\":\"400\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-400\"},
                  {\"uri\":\"/signin\",\"responseCode\":\"404\",\"showCount\":1,\"skipCount\":1,\"errorCodes\":\"ER-404\"}]"
```

### Sampling Runtime Behavior

- `20X`: rule key is `"#{uri}|#{responseCode}"`.
- `40X`: rule key is `"#{uri}|#{derived_error_code}"`.
- For `40X`, `derived_error_code` is built from the first two segments of `internal_error_code`.
  - Example: `"ER-409-01-01" -> "ER-409"`.
- If no matching rule is found, the log is printed.
- If sampling config cannot be parsed/loaded, the log is printed (fail-open).
- For matching rules:
  - `cycle = showCount + skipCount`
  - log is printed when `position < showCount`
  - counters rotate by cycle.

## Usage

### Basic Logging

```elixir
# Simple error logging
ElixirEcsLogger.log_ecs(%{
  error_code: "USER_001",
  error_message: "User validation failed"
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
  consumer: "user_service"
})
```

### Log Levels

The library supports the following log levels:

- `"DEBUG"` - Detailed information for debugging
- `"INFO"` - General information messages
- `"WARNING"` - Warning messages for potential issues
- `"ERROR"` - Error messages for handled exceptions
- `"CRITICAL"` - Critical errors that may cause application failure

```elixir
# Debug level logging
ElixirEcsLogger.log_ecs(%{
  error_code: "DEBUG_001",
  error_message: "Processing user request",
  level: "DEBUG"
})

# Critical level logging
ElixirEcsLogger.log_ecs(%{
  error_code: "CRIT_001",
  error_message: "Database connection lost",
  level: "CRITICAL"
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
          additional_details: %{user_id: user.id}
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
          consumer: "user_service"
        })
        {:error, reason}
    end
  end
end
```

### Host API Integration In Global Response/Error Handlers

Add ECS logging in both your global response and error handlers.

#### Success

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

#### Error

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

### Important Integration Notes

- `additional_info.uri` and `additional_info.responseCode` are required for sampling decisions.
- Keep `internal_error_code` in a derivable format for `40X` matching.
  - Recommended format: `PREFIX-CODE-...` (example: `ER-409-01-01`).
- Ensure logging is invoked from central/global handlers to avoid missing requests.

## API Documentation

### ElixirEcsLogger.log_ecs/1

Logs a structured message in ECS format.

**Parameters:**
- `attrs` (map) - Logging attributes

**Required attributes:**
- `error_code` (string) - Unique error code identifier
- `error_message` (string) - Human-readable error message

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
  "additionalInfo": null,
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

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`mix test`)
6. Run code formatting (`mix format`)
7. Run static analysis (`mix credo`)
8. Commit your changes (`git commit -m 'feat(user_module): Add amazing feature'`)
9. Push to the branch (`git push origin feature/amazing-feature`)
10. Open a Pull Request

### Development Guidelines

- Follow Elixir naming conventions
- Write comprehensive tests for new features
- Update documentation for API changes
- Ensure code passes all quality checks
- Add typespecs for public functions
