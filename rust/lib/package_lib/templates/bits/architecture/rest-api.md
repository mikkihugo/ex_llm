# REST API Architecture

## Design Principles

### Resource-Based URLs

```
✅ Good:
GET    /users           - List users
GET    /users/{id}      - Get specific user
POST   /users           - Create user
PUT    /users/{id}      - Update user
DELETE /users/{id}      - Delete user

❌ Bad:
GET    /getUser?id=123
POST   /createNewUser
POST   /users/delete/123
```

### HTTP Methods Semantics

- **GET**: Read-only, idempotent, cacheable
- **POST**: Create, non-idempotent
- **PUT**: Update (full replacement), idempotent
- **PATCH**: Partial update, idempotent
- **DELETE**: Remove, idempotent

### Status Codes

```
200 OK                  - Successful GET, PUT, PATCH
201 Created            - Successful POST
204 No Content         - Successful DELETE
400 Bad Request        - Invalid input
401 Unauthorized       - Missing/invalid auth
403 Forbidden          - Authenticated but not authorized
404 Not Found          - Resource doesn't exist
422 Unprocessable      - Validation error
429 Too Many Requests  - Rate limit exceeded
500 Internal Error     - Server error
```

## Response Format

### Success Response

```json
{
  "id": "123",
  "name": "John Doe",
  "email": "john@example.com",
  "created_at": "2025-10-04T12:00:00Z",
  "updated_at": "2025-10-04T12:00:00Z"
}
```

### Error Response

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      }
    ]
  }
}
```

### Pagination

```json
{
  "data": [...],
  "pagination": {
    "total": 100,
    "page": 1,
    "per_page": 20,
    "total_pages": 5
  },
  "links": {
    "first": "/users?page=1",
    "prev": null,
    "next": "/users?page=2",
    "last": "/users?page=5"
  }
}
```

## Best Practices

1. **Versioning**: Use URL versioning (`/v1/users`) or header versioning
2. **HATEOAS**: Include links to related resources
3. **Filtering**: `GET /users?role=admin&status=active`
4. **Sorting**: `GET /users?sort=-created_at` (- for descending)
5. **Field selection**: `GET /users?fields=id,name,email`
6. **Content negotiation**: Support JSON, use Accept headers
7. **Rate limiting**: Include `X-RateLimit-*` headers
8. **CORS**: Configure properly for web clients
