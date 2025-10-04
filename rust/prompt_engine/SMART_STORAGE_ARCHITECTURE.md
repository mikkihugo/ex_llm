# Smart Storage Architecture

## ✨ The Best of Both Worlds

**Prompt Definitions (PromptBits)** → JSON files (editable, git-trackable)
**Everything Else** → redb (fast, efficient)

## 📂 Storage Layout

```
storage_path/
├── prompt_facts.redb          # All performance data (executions, feedback, etc)
└── prompts/                   # JSON prompt definitions (git-trackable!)
    ├── builtin/               # Built-in prompts
    │   ├── nextjs-app-router.json
    │   ├── rust-error-handling.json
    │   └── ...
    ├── learned/               # AI-generated/evolved prompts
    │   ├── auth-service-v2.json
    │   └── ...
    └── custom/                # User-created prompts
        ├── company-specific.json
        └── ...
```

## 🎯 Why This Split?

### Prompts in JSON (Git-trackable)
- **Edit manually** - Fix typos, improve wording, add examples
- **Git history** - See how prompts evolved over time
- **Code review** - Review prompt changes in PRs
- **Share** - Export/import prompt libraries
- **Transparency** - See exactly what prompts AI uses

### Everything Else in redb (Performance)
- **Executions** - Millions of execution records
- **Feedback** - User corrections and ratings
- **Context signatures** - ML feature vectors
- **Code index** - Repository analysis
- **Tech stack** - Technology detection
- **Patterns** - Architecture patterns
- **Evolutions** - How prompts improved
- **A/B tests** - Scientific comparisons

## 📝 Example Prompt in JSON

```json
// prompts/builtin/nextjs-app-router.json
{
  "id": "nextjs-app-router",
  "trigger": {
    "Framework": "Next.js"
  },
  "category": "Commands",
  "content": "## Next.js App Router\n\nCreate pages in `app/` directory:\n\n```typescript\n// app/page.tsx\nexport default function Page() {\n  return <h1>Hello Next.js!</h1>\n}\n```\n\nAPI routes in `app/api/`:\n\n```typescript\n// app/api/route.ts\nexport async function GET() {\n  return Response.json({ hello: 'world' })\n}\n```",
  "confidence": 0.95,
  "source": "Builtin",
  "tags": ["nextjs", "react", "typescript"],
  "version": "14.0+"
}
```

## 🚀 Benefits

1. **Edit prompts in your IDE** - JSON files are just text
2. **Git tracks prompt changes** - See diffs, history, blame
3. **Performance unaffected** - Execution data stays in redb
4. **Best practice sharing** - Commit good prompts to repo
5. **Easy debugging** - Read prompts without special tools

## 🔧 Usage

```rust
// Store a prompt (goes to JSON)
let prompt = PromptBit {
    id: "my-prompt",
    content: "Do something specific",
    // ...
};
storage.store_prompt(prompt).await?;

// Store execution data (goes to redb)
let execution = PromptExecutionFact {
    prompt_bit_id: "my-prompt",
    success_rate: 0.95,
    // ...
};
storage.store(PromptFactType::PromptExecution(execution)).await?;

// Query everything (fast from redb)
let executions = storage.query(
    FactQuery::PromptExecutions("my-prompt")
).await?;

// Get prompt definition (from JSON)
let prompt = storage.get_prompt("my-prompt").await?;
```

## 🎨 Workflow

1. **Create/edit** prompt in `prompts/custom/my-prompt.json`
2. **Test** prompt with your code
3. **System tracks** execution in redb
4. **AI learns** from feedback and evolves prompt
5. **New version** saved to `prompts/learned/my-prompt-v2.json`
6. **Git commit** both versions for history
7. **Review** changes in PR
8. **Merge** improved prompt

This gives you the **speed of redb** with the **editability of JSON**!