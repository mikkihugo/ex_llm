# Rate Limiting

## Implementation Guidelines

### FastAPI with slowapi

```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi import FastAPI, Request

limiter = Limiter(key_func=get_remote_address)
app = FastAPI()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@app.get("/api/endpoint")
@limiter.limit("10/minute")
async def limited_endpoint(request: Request):
    return {"message": "Success"}
```

### Rust with Governor

```rust
use axum::{
    extract::State,
    http::StatusCode,
    middleware,
    response::IntoResponse,
    Router,
};
use governor::{Quota, RateLimiter};
use std::sync::Arc;

type AppState = Arc<RateLimiter<String, DefaultDirectRateLimiter, DefaultClock>>;

async fn rate_limit_middleware(
    State(limiter): State<AppState>,
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let key = request
        .headers()
        .get("x-forwarded-for")
        .and_then(|h| h.to_str().ok())
        .unwrap_or("unknown")
        .to_string();

    match limiter.check_key(&key) {
        Ok(_) => Ok(next.run(request).await),
        Err(_) => Err(StatusCode::TOO_MANY_REQUESTS),
    }
}
```

## Configuration Guidelines

- **Public endpoints**: 100 requests/minute
- **Authenticated endpoints**: 1000 requests/minute
- **Write operations**: 10 requests/minute
- **Use distributed rate limiting** for multi-instance deployments (Redis)
