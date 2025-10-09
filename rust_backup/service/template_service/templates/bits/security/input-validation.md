# Input Validation

## Implementation Guidelines

### FastAPI with Pydantic

```python
from pydantic import BaseModel, Field, validator, EmailStr
from typing import Optional

class UserInput(BaseModel):
    username: str = Field(..., min_length=3, max_length=50, regex="^[a-zA-Z0-9_-]+$")
    email: EmailStr
    age: Optional[int] = Field(None, ge=0, le=150)

    @validator('username')
    def username_alphanumeric(cls, v):
        assert v.isalnum() or '_' in v or '-' in v, 'must be alphanumeric with _ or -'
        return v.lower()

    @validator('email')
    def email_must_be_lowercase(cls, v):
        return v.lower()
```

### Rust with validator crate

```rust
use validator::{Validate, ValidationError};
use serde::{Deserialize, Serialize};

#[derive(Debug, Validate, Deserialize, Serialize)]
struct UserInput {
    #[validate(length(min = 3, max = 50), regex = "^[a-zA-Z0-9_-]+$")]
    username: String,

    #[validate(email)]
    email: String,

    #[validate(range(min = 0, max = 150))]
    age: Option<u8>,
}

fn validate_user_input(input: &UserInput) -> Result<(), ValidationError> {
    input.validate()
}
```

## Validation Rules

1. **Whitelist over blacklist** - Define what's allowed, not what's forbidden
2. **Validate at boundaries** - API entry points, not internal functions
3. **Sanitize output** - Escape data when rendering to prevent XSS
4. **Use type systems** - Let Rust/Pydantic enforce constraints
5. **Validate file uploads** - Check MIME types, size limits, content
6. **SQL injection prevention** - Use parameterized queries always
