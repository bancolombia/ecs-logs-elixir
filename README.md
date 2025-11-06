# Elixir ECS Library

A comprehensive Elixir library that enables structured logging in ECS (Elastic Common Schema) format, providing standardized log output for better observability and monitoring in Elixir applications.

## Installation

Add `ecs_logs_elixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecs_logs_elixir, 
    sparse: "ecs_logs_elixir",
    git: "https://grupobancolombia.visualstudio.com/Vicepresidencia%20Servicios%20de%20Tecnolog%C3%ADa/_git/NU0141001_Library_MR"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Configuration

### Service Name Configuration

Configure your service name in `config/config.exs`:

```elixir
config :ecs_logs_elixir,
  service_name: "my_application"
```

If no service name is configured, it defaults to `"INDEFINIDO"`.

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

# Run specific test file
mix test test/ecs_logs/ecs/elixir_ecs_logger_test.exs
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
8. Commit your changes (`git commit -m 'Add amazing feature'`)
9. Push to the branch (`git push origin feature/amazing-feature`)
10. Open a Pull Request

### Development Guidelines

- Follow Elixir naming conventions
- Write comprehensive tests for new features
- Update documentation for API changes
- Ensure code passes all quality checks
- Add typespecs for public functions
