# Caching Strategies

## Implementation Guidelines

### FastAPI with Redis

```python
import redis.asyncio as redis
from fastapi import FastAPI, Depends
import json
from typing import Optional

app = FastAPI()
redis_client = redis.from_url("redis://localhost")

async def get_cached_data(key: str) -> Optional[dict]:
    """Get data from cache."""
    cached = await redis_client.get(key)
    return json.loads(cached) if cached else None

async def set_cached_data(key: str, data: dict, ttl: int = 300):
    """Set data in cache with TTL."""
    await redis_client.setex(key, ttl, json.dumps(data))

@app.get("/users/{user_id}")
async def get_user(user_id: str):
    # Try cache first
    cache_key = f"user:{user_id}"
    cached = await get_cached_data(cache_key)
    if cached:
        return cached

    # Cache miss - fetch from DB
    user = await fetch_user_from_db(user_id)
    await set_cached_data(cache_key, user, ttl=600)
    return user
```

### Rust with fred (Redis client)

```rust
use fred::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
struct User {
    id: String,
    name: String,
}

async fn get_user_cached(
    redis: &RedisClient,
    user_id: &str,
) -> Result<User, Box<dyn std::error::Error>> {
    let cache_key = format!("user:{}", user_id);

    // Try cache first
    if let Some(cached) = redis.get::<Option<String>, _>(&cache_key).await? {
        return Ok(serde_json::from_str(&cached)?);
    }

    // Cache miss
    let user = fetch_user_from_db(user_id).await?;
    let serialized = serde_json::to_string(&user)?;
    redis.set(&cache_key, serialized, Some(Expiration::EX(600)), None, false).await?;

    Ok(user)
}
```

## Caching Strategies

### Cache-Aside (Lazy Loading)
- Application checks cache first
- On miss, fetch from DB and populate cache
- Best for: Read-heavy workloads

### Write-Through
- Write to cache and DB simultaneously
- Ensures cache is always fresh
- Best for: Data consistency requirements

### Write-Behind
- Write to cache immediately
- Async write to DB
- Best for: High write throughput

## TTL Guidelines

- **User profiles**: 10-60 minutes
- **Configuration**: 1-24 hours
- **Session data**: Match session lifetime
- **API responses**: 1-5 minutes
- **Static content**: 24 hours - 7 days
