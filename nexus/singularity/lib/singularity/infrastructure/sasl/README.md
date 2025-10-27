# SASL (Simple Authentication and Security Layer) Implementation

This module provides comprehensive SASL authentication and security mechanisms for telecommunications systems, including support for Diameter, RADIUS, SS7, and standard SCRAM protocols.

## Overview

The SASL implementation extends standard Erlang SASL with telecom-specific authentication mechanisms commonly used in network equipment. It provides:

- **Multiple SASL Mechanisms**: Diameter, RADIUS, SS7, and SCRAM authentication
- **Telecom Protocol Integration**: Native support for telecom protocols
- **High-Performance Rust Backend**: Cryptographic operations via Rust NIFs
- **Security Policy Enforcement**: Integration with security validator
- **Audit and Compliance**: Comprehensive security event logging

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Singularity SASL                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐ │
│  │   Diameter  │ │   RADIUS    │ │     SS7     │ │  SCRAM  │ │
│  │  Mechanism  │ │  Mechanism  │ │  Mechanism  │ │Mechanism│ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐ │
│  │   Protocol  │ │   Security  │ │    Crypto   │ │   Rust  │ │
│  │  Adapters   │ │  Policies   │ │ Operations  │ │   NIF   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Basic Authentication

```elixir
alias Singularity.Infrastructure.Sasl

# Authenticate using Diameter mechanism (default)
{:ok, context} = Sasl.authenticate(%{
  username: "admin",
  password: "secret"
}, :diameter)

# Authenticate using RADIUS mechanism
{:ok, context} = Sasl.authenticate(%{
  username: "network_user",
  password: "network_secret"
}, :radius)

# Authenticate using SS7 mechanism
{:ok, context} = Sasl.authenticate(%{
  username: "switch_user",
  password: "switch_secret"
}, :ss7)
```

### Protocol-Specific Authentication

```elixir
alias Singularity.Infrastructure.Sasl.ProtocolAdapter

# Diameter authentication with protocol message
diameter_message = %{
  avps: [
    {"User-Name", "admin"},
    {"Session-Id", "session_123"},
    {"Origin-Host", "hss.singularity"}
  ]
}

{:ok, context} = ProtocolAdapter.authenticate_protocol(
  %{username: "admin", password: "secret"},
  :diameter,
  diameter_message
)

# RADIUS authentication with protocol message
radius_request = %{
  code: "Access-Request",
  attributes: [
    {"User-Name", "user"},
    {"NAS-IP-Address", "192.168.1.1"}
  ]
}

{:ok, context} = ProtocolAdapter.authenticate_protocol(
  %{username: "user", password: "pass"},
  :radius,
  radius_request
)
```

### Challenge-Response Authentication

```elixir
# Generate challenge
{:ok, challenge} = Sasl.generate_challenge(:diameter)

# Client computes response (in real implementation)
response = compute_client_response(challenge, credentials)

# Server verifies response
{:ok, context} = Sasl.verify_response(challenge, response, :diameter)
```

## Supported Mechanisms

### 1. Diameter SASL

Used in 3G/4G/5G networks for authentication and authorization.

```elixir
# Features
# - Mutual authentication using challenge-response
# - AVP (Attribute-Value Pair) support
# - Session management
# - Telecom-grade security

{:ok, info} = Sasl.get_mechanism_info(:diameter)
# => %{name: "Diameter SASL", security_level: :high, features: [...]}
```

### 2. RADIUS SASL

Used for network access authentication in telecom and enterprise networks.

```elixir
# Features
# - PAP (Password Authentication Protocol)
# - CHAP (Challenge-Handshake Authentication Protocol)
# - MS-CHAP (Microsoft CHAP)
# - RADIUS attributes and VSAs

{:ok, info} = Sasl.get_mechanism_info(:radius)
# => %{name: "RADIUS SASL", security_level: :medium, features: [...]}
```

### 3. SS7 SASL

Used for legacy SS7 network authentication and signaling.

```elixir
# Features
# - SCCP (Signaling Connection Control Part) authentication
# - TCAP (Transaction Capabilities Application Part) security
# - Global Title routing
# - Point Code validation

{:ok, info} = Sasl.get_mechanism_info(:ss7)
# => %{name: "SS7 SASL", security_level: :medium, features: [...]}
```

### 4. SCRAM SASL

Standard SCRAM authentication (RFC 5802), PostgreSQL compatible.

```elixir
# Features
# - SCRAM-SHA-256 (recommended)
# - SCRAM-SHA-1 (legacy support)
# - PBKDF2 password hashing
# - Channel binding support

{:ok, info} = Sasl.get_mechanism_info(:standard_scram)
# => %{name: "SCRAM SASL", security_level: :high, features: [...]}
```

## Configuration

### Basic Configuration

```elixir
# config/config.exs
config :singularity, :sasl,
  mechanisms: [:diameter, :radius, :ss7, :standard_scram],
  default_mechanism: :diameter,
  security: %{
    min_password_length: 12,
    require_special_chars: true,
    max_auth_attempts_per_minute: 5,
    default_session_timeout: 3600,
    max_session_timeout: 86400
  }
```

### Telecom-Specific Configuration

```elixir
config :singularity, :sasl,
  telecom: %{
    enable_telecom_protocols: true,
    protocols: [:diameter, :radius, :ss7, :sigtran],
    nas: %{
      default_identifier: "singularity-nas",
      ip_address: "192.168.1.100",
      auth_methods: [:pap, :chap, :mschap]
    },
    ss7: %{
      default_point_code: "1-234-5",
      default_subsystem: 3,
      global_title_translation: true
    }
  }
```

### Database Integration

```elixir
config :singularity, :sasl,
  database: %{
    user_table: "sasl_users",
    auto_provisioning: false,
    password_hash_algorithm: :pbkdf2_sha256,
    password_hash_iterations: 100_000
  }
```

## Security Features

### Context Validation

```elixir
# Validate security context for operations
{:ok, context} = Sasl.validate_context(
  context,
  :database_access,
  "user_data"
)

# Check permissions
if Sasl.Security.has_permissions?(context, ["admin"]) do
  # Allow admin operations
end

# Check session expiration
if Sasl.Security.session_expired?(context) do
  # Session has expired
end
```

### Audit Logging

All security events are automatically logged:

```elixir
# Authentication events
# - Successful authentication
# - Failed authentication attempts
# - Session creation/termination
# - Permission violations
# - Security policy violations
```

### Security Policies

```elixir
# Resource-specific access policies
policy = %{
  required_permissions: ["admin"],
  max_session_timeout: 1800,
  allowed_operations: [:read, :write]
}

{:ok, context} = Sasl.Security.validate_resource_access(
  context,
  :admin_operation,
  "admin/resource"
)
```

## Integration with Security Validator

The SASL implementation integrates with the existing security validator:

```elixir
# Security validator automatically checks for SASL violations
code = """
def authenticate(user_input) do
  :crypto.hash_equals(user_input, "password")  # Missing crypto.hash_equals
end
"""

{:error, violations} = Singularity.Validators.SecurityValidator.validate(code)
# => Includes SASL security violations
```

## Rust Integration

High-performance cryptographic operations are implemented in Rust:

```rust
// Rust NIF implementation provides:
// - PBKDF2 password hashing
// - HMAC computation
// - Challenge-response verification
// - Constant-time comparison
```

### Performance Benefits

- **Cryptographic Operations**: 10-100x faster than pure Elixir
- **Memory Safety**: Zero unsafe code, comprehensive bounds checking
- **Parallel Processing**: Cryptographic operations can be parallelized

## Testing

### Unit Tests

```bash
# Run SASL tests
mix test test/infrastructure/sasl_test.exs

# Run mechanism-specific tests
mix test test/infrastructure/sasl/mechanism/diameter_test.exs
mix test test/infrastructure/sasl/protocol_adapter_test.exs

# Run with coverage
mix test --cover
```

### Integration Tests

```elixir
# Test protocol integration
test "diameter protocol integration" do
  credentials = %{username: "admin", password: "secret"}
  message = %{avps: [{"User-Name", "admin"}]}

  assert {:ok, context} = ProtocolAdapter.authenticate_protocol(
    credentials,
    :diameter,
    message
  )
end
```

## Error Handling

### Authentication Errors

```elixir
case Sasl.authenticate(credentials, :diameter) do
  {:ok, context} ->
    # Authentication successful
    handle_success(context)

  {:error, "Authentication failed: Invalid credentials"} ->
    # Invalid username/password
    handle_invalid_credentials()

  {:error, "Authentication failed: User not found"} ->
    # User does not exist
    handle_user_not_found()

  {:error, "Authentication failed: Session expired"} ->
    # Session has expired
    handle_session_expired()
end
```

### Protocol Errors

```elixir
case ProtocolAdapter.authenticate_protocol(credentials, :diameter, message) do
  {:ok, context} ->
    # Protocol authentication successful
    handle_protocol_success(context)

  {:error, "Protocol authentication failed: Unsupported mechanism"} ->
    # Protocol not supported
    handle_unsupported_protocol()

  {:error, "Protocol authentication failed: Invalid message format"} ->
    # Malformed protocol message
    handle_invalid_message()
end
```

## Best Practices

### 1. Use Strong Passwords

```elixir
# Configure strong password requirements
config :singularity, :sasl, security: %{
  min_password_length: 16,
  require_special_chars: true,
  require_numbers: true,
  require_uppercase: true
}
```

### 2. Implement Session Management

```elixir
# Check session validity before operations
context = get_user_context()
case Sasl.validate_context(context, :operation, "resource") do
  {:ok, valid_context} -> proceed_with_operation()
  {:error, reason} -> handle_security_violation(reason)
end
```

### 3. Use Appropriate Mechanisms

```elixir
# Choose mechanism based on security requirements
case security_level do
  :high -> Sasl.authenticate(credentials, :diameter)
  :medium -> Sasl.authenticate(credentials, :radius)
  :legacy -> Sasl.authenticate(credentials, :ss7)
end
```

### 4. Enable Audit Logging

```elixir
# Ensure audit logging is enabled
config :singularity, :sasl, security: %{
  audit_logging: true,
  security_notifications: true
}
```

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Check credentials format
   - Verify user exists in database
   - Check password complexity requirements

2. **Session Timeouts**
   - Verify session timeout configuration
   - Check system clock synchronization
   - Monitor session activity

3. **Protocol Integration Issues**
   - Validate protocol message format
   - Check AVP/attribute requirements
   - Verify network connectivity

### Debug Logging

```elixir
# Enable debug logging for troubleshooting
Logger.configure(level: :debug)

# SASL operations will log detailed information
{:ok, context} = Sasl.authenticate(credentials, :diameter)
# Logs: "SASL authentication attempt: mechanism=diameter"
# Logs: "SASL authentication successful: mechanism=diameter"
```

## Migration from Standard SASL

If migrating from standard Erlang SASL:

1. **Update Configuration**
   ```elixir
   # Replace standard SASL config
   config :sasl, sasl_error_logger: :false  # Disable standard SASL logging

   # Add enhanced SASL config
   config :singularity, :sasl, mechanisms: [:diameter, :radius]
   ```

2. **Update Authentication Code**
   ```elixir
   # Old: Using standard SASL
   # :sasl.report_cb(fun(_,_) -> ok end)

   # New: Using enhanced SASL
   {:ok, context} = Sasl.authenticate(credentials, :diameter)
   ```

3. **Update Security Policies**
   ```elixir
   # Implement security context validation
   case Sasl.validate_context(context, :operation, "resource") do
     {:ok, _} -> allow_access()
     {:error, _} -> deny_access()
   end
   ```

## Performance Considerations

### Cryptographic Operations

- **Rust NIFs**: Use for all cryptographic operations
- **Batch Processing**: Process multiple authentications together
- **Connection Pooling**: Reuse SASL contexts when possible

### Memory Usage

- **Context Caching**: Cache validated contexts for performance
- **Session Cleanup**: Implement automatic session cleanup
- **Resource Limits**: Set appropriate limits for concurrent sessions

### Network Protocols

- **Connection Reuse**: Reuse protocol connections when possible
- **Message Batching**: Batch protocol messages for efficiency
- **Async Processing**: Use asynchronous authentication for better performance

## Security Considerations

### 1. Password Security

- Use PBKDF2 with high iteration counts (100,000+)
- Implement password complexity requirements
- Enable automatic password rotation

### 2. Session Security

- Implement session timeout enforcement
- Use secure session identifiers
- Enable session invalidation on suspicious activity

### 3. Protocol Security

- Validate all protocol messages
- Implement replay protection
- Use mutual authentication when possible

### 4. Audit and Compliance

- Log all authentication events
- Implement security event alerting
- Maintain audit trails for compliance

## Contributing

When contributing to the SASL implementation:

1. **Add Tests**: All new features must have comprehensive tests
2. **Update Documentation**: Keep documentation current
3. **Security Review**: All security-related changes require review
4. **Performance Testing**: Validate performance impact of changes

## License

This SASL implementation is part of the Singularity project and follows the same license terms.