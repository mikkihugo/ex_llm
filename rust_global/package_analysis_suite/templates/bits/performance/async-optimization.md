# Async Optimization

## Implementation Guidelines

### FastAPI Async Best Practices

```python
import asyncio
from typing import List

# ✅ Good: Concurrent I/O operations
async def fetch_user_data(user_ids: List[str]):
    tasks = [fetch_user(uid) for uid in user_ids]
    return await asyncio.gather(*tasks)

# ✅ Good: Use async database drivers
from databases import Database
database = Database("postgresql://...")

async def get_users():
    query = "SELECT * FROM users"
    return await database.fetch_all(query)

# ❌ Bad: Blocking calls in async functions
async def bad_example():
    result = requests.get("https://api.example.com")  # Blocks event loop!
    return result.json()

# ✅ Good: Use async HTTP client
import httpx
async def good_example():
    async with httpx.AsyncClient() as client:
        response = await client.get("https://api.example.com")
        return response.json()
```

### Rust Async with Tokio

```rust
use tokio::task::JoinSet;

// Concurrent task execution
async fn fetch_multiple_resources(ids: Vec<String>) -> Vec<Result<Data, Error>> {
    let mut set = JoinSet::new();

    for id in ids {
        set.spawn(async move {
            fetch_resource(&id).await
        });
    }

    let mut results = Vec::new();
    while let Some(res) = set.join_next().await {
        results.push(res.unwrap());
    }
    results
}

// Connection pooling
use sqlx::postgres::PgPoolOptions;

async fn create_db_pool() -> sqlx::PgPool {
    PgPoolOptions::new()
        .max_connections(5)
        .connect("postgres://...")
        .await
        .unwrap()
}
```

## Optimization Checklist

- ✅ Use async I/O for database, HTTP, file operations
- ✅ Pool connections (DB, HTTP clients)
- ✅ Run independent tasks concurrently
- ✅ Use appropriate buffer sizes
- ❌ Don't await in loops - use gather/join
- ❌ Don't block the event loop with CPU-intensive work
