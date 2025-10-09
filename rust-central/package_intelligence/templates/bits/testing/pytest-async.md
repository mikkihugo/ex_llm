# Pytest Async Testing

## Implementation Guidelines

### Basic Async Test Setup

```python
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.fixture
async def client():
    """Async test client fixture."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.fixture
async def db_session():
    """Database session fixture with cleanup."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSession(engine) as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
```

### Test Examples

```python
@pytest.mark.asyncio
async def test_get_user_success(client: AsyncClient, db_session):
    """Test successful user retrieval."""
    # Setup: Create test user
    user = User(id="123", name="Test User")
    db_session.add(user)
    await db_session.commit()

    # Execute
    response = await client.get("/users/123")

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "123"
    assert data["name"] == "Test User"

@pytest.mark.asyncio
async def test_get_user_not_found(client: AsyncClient):
    """Test user not found returns 404."""
    response = await client.get("/users/nonexistent")
    assert response.status_code == 404
    assert "not found" in response.json()["detail"].lower()

@pytest.mark.asyncio
async def test_create_user_validation_error(client: AsyncClient):
    """Test validation error on invalid input."""
    payload = {"name": ""}  # Empty name should fail validation
    response = await client.post("/users", json=payload)
    assert response.status_code == 422

@pytest.mark.asyncio
async def test_concurrent_requests(client: AsyncClient):
    """Test handling concurrent requests."""
    import asyncio

    async def make_request(user_id: str):
        return await client.get(f"/users/{user_id}")

    # Make 10 concurrent requests
    tasks = [make_request(f"user{i}") for i in range(10)]
    responses = await asyncio.gather(*tasks)

    assert all(r.status_code in [200, 404] for r in responses)
```

### Mocking Async Dependencies

```python
from unittest.mock import AsyncMock, patch

@pytest.mark.asyncio
async def test_external_api_call(client: AsyncClient):
    """Test with mocked external API."""
    with patch('app.services.external_api_call', new=AsyncMock(return_value={"data": "mocked"})):
        response = await client.get("/external-data")
        assert response.status_code == 200
        assert response.json() == {"data": "mocked"}
```

## Best Practices

- Use `@pytest.mark.asyncio` for all async tests
- Clean up database state between tests
- Mock external dependencies
- Test both success and error paths
- Use fixtures for common setup
- Test concurrent scenarios when relevant
