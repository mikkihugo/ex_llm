# Correct Prompt-Engine Architecture

## You're Right! The Assembler Should ASSEMBLE, Not Generate

### ❌ Current (Wrong) Implementation:
```rust
// assembler.rs is generating content directly
fn generate_auth_prompt() {
    // Hardcoding content - WRONG!
    section.push_str("Use JWT tokens...");
}
```

### ✅ Correct Architecture:

## 1. **Prompt Bits** (Stored in Database)

```json
// prompts/builtin/nextjs-routing.json
{
  "id": "nextjs-routing",
  "trigger": {"Framework": "Next.js"},
  "category": "Commands",
  "content": "Create pages in app/ directory:\n```tsx\nexport default function Page() {...}\n```"
}

// prompts/builtin/jwt-auth.json
{
  "id": "jwt-auth",
  "trigger": {"Pattern": "Authentication"},
  "category": "Security",
  "content": "Use JWT with refresh tokens:\n- Access token: 15min\n- Refresh token: 7 days"
}

// prompts/learned/your-repo-structure.json
{
  "id": "your-services-location",
  "trigger": {"Repository": "your-repo-hash"},
  "category": "FileLocation",
  "content": "Create services in packages/services/"
}
```

## 2. **Assembler** (Combines Relevant Bits)

```rust
// CORRECT assembler.rs implementation
impl PromptBitAssembler {
    pub async fn assemble(&self, task: TaskType, context: &Context) -> GeneratedPrompt {
        // 1. Query relevant prompt bits
        let bits = self.database.query_bits(QueryBuilder {
            task_type: task,
            tech_stack: context.tech_stack,
            patterns: context.patterns,
            repository: context.repo_fingerprint,
        }).await?;

        // 2. Rank by relevance
        let ranked_bits = self.rank_by_relevance(bits, context);

        // 3. ASSEMBLE the prompt from bits
        let mut prompt = String::new();

        for bit in ranked_bits {
            prompt.push_str(&format!("## {}\n", bit.category));
            prompt.push_str(&bit.content);
            prompt.push_str("\n\n");
        }

        GeneratedPrompt {
            content: prompt,
            sources: ranked_bits.map(|b| b.id),
            confidence: self.calculate_confidence(&ranked_bits),
        }
    }
}
```

## 3. **The Flow**

```
User: "Add authentication"
         ↓
[Context Analysis]
- Repository: monorepo with Next.js
- Existing: PostgreSQL, NATS
- Pattern: Microservices
         ↓
[Query Prompt Bits]
- Find: Authentication bits
- Find: Next.js bits
- Find: PostgreSQL connection bits
- Find: NATS messaging bits
- Find: Your repo-specific bits
         ↓
[Assembler ASSEMBLES]
Combines relevant bits into cohesive prompt:
1. File location (from repo-specific bit)
2. JWT implementation (from auth bit)
3. Next.js setup (from framework bit)
4. Database connection (from PostgreSQL bit)
5. Event publishing (from NATS bit)
         ↓
[Output: Assembled Prompt]
Hyper-specific to your exact context
```

## 4. **Learning Loop**

```
After execution:
- Track which bits were used
- Record success/failure
- Learn new bits from modifications
- Store learned bits for future use
```

## The Key Insight

**The Assembler is like a DJ mixing tracks:**
- Prompt bits = Individual tracks (stored)
- Assembler = DJ mixing relevant tracks
- Output = Custom mix for this specific request

**NOT like a band writing new songs!**

## Benefits of Correct Architecture

1. **Reusable**: Each bit used across many prompts
2. **Learnable**: New bits learned from experience
3. **Maintainable**: Edit individual bits in JSON
4. **Scalable**: Add new bits without changing code
5. **Git-trackable**: See history of each bit

## Example: Real Assembly

**Task**: "Add auth to Next.js app"

**Selected Bits**:
- `nextjs-app-router` (Framework bit)
- `jwt-authentication` (Pattern bit)
- `your-repo-services` (Repo-specific bit)
- `postgresql-connection` (Database bit)
- `nats-events` (Messaging bit)

**Assembled Output**:
```markdown
## File Location
Create in: `packages/services/auth/` [from your-repo-services]

## Framework Setup
Use Next.js App Router... [from nextjs-app-router]

## Authentication
Implement JWT with... [from jwt-authentication]

## Database
Connect to PostgreSQL... [from postgresql-connection]

## Events
Publish to NATS... [from nats-events]
```

Each section comes from a stored, reusable, learnable prompt bit!