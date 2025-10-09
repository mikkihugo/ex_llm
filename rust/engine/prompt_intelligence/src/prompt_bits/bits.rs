//! Library of reusable prompt fragments
//!
//! Can be expanded as we learn what works

/// Common prompt bits that can be reused
pub const SECURITY_BEST_PRACTICES: &str = r#"
## Security Best Practices

- Never store passwords in plain text (use bcrypt/argon2)
- Use environment variables for secrets
- Implement rate limiting on auth endpoints
- Add CORS configuration
- Validate all inputs
- Use HTTPS in production
- Implement proper JWT expiration
- Add audit logging (but never log passwords/tokens)
"#;

pub const TESTING_GUIDELINES: &str = r#"
## Testing

- Write unit tests for all handlers
- Add integration tests for auth flow
- Test failure cases (invalid tokens, expired sessions)
- Mock external dependencies
- Aim for >80% code coverage
"#;

pub const MICROSERVICES_COMMUNICATION: &str = r#"
## Service Communication

- Use async messaging for non-critical operations
- Use sync REST/gRPC for critical operations
- Implement circuit breakers
- Add retry logic with exponential backoff
- Health check endpoint: `/health`
- Readiness endpoint: `/ready`
"#;

pub const MONOREPO_CONVENTIONS: &str = r#"
## Monorepo Conventions

- Follow existing directory structure
- Use workspace dependencies for shared code
- Keep services loosely coupled
- Document cross-service dependencies
"#;

// Add more bits as we learn what works well
