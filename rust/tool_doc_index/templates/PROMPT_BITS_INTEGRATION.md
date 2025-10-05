# Prompt Bits + Code Templates Integration

## Architecture

```
Template System (tool_doc_index)        Prompt Bits (prompt_engine)
========================                ===========================

rust-fastapi.json                       PromptBit: "Python FastAPI Best Practices"
├─ ai_signature                         ├─ Trigger: Language(Python) + Framework(FastAPI)
├─ detector_signatures                  ├─ Content: "Use async handlers, Pydantic v2..."
├─ template_content  ────────┬─────────>├─ Category: BestPractices
└─ metadata                  │          └─ Confidence: 0.95
                             │
                             │          PromptBit: "FastAPI Project Structure"
                             └─────────>├─ Trigger: CodePattern("FastAPI")
                                       ├─ Content: "app/, models/, schemas/..."
                                       └─ Category: ProjectStructure

                                       PromptBit: "FastAPI Security Patterns"
                                       ├─ Trigger: Task(AddAuthentication)
                                       ├─ Content: "Use OAuth2PasswordBearer..."
                                       └─ Category: Security
```

## Integration Points

### 1. **Template Contains Prompt Bit References**

```json
{
  "id": "python-fastapi-endpoint",
  "ai_signature": {
    "instruction": "Generate FastAPI endpoint with...",
    "prompt_bits": [
      "fastapi-best-practices",
      "python-async-patterns",
      "pydantic-validation"
    ]
  },
  "detector_signatures": {
    "dependencies": ["fastapi", "pydantic"],
    "auto_load_prompt_bits": true
  }
}
```

### 2. **Prompt Bits Enhance Template Context**

```rust
// When loading template
let template = registry.get("python-fastapi-endpoint")?;

// Auto-load referenced prompt bits
let prompt_bits = if template.detector_signatures.auto_load_prompt_bits {
    load_prompt_bits_for_template(&template).await?
} else {
    vec![]
};

// Build enhanced context
let context = TemplateContext::builder()
    .from_detection(&detection_result)
    .with_prompt_bits(prompt_bits)  // ← Enhanced!
    .build();

// Expand template WITH prompt bits
let enhanced_prompt = template_expander.expand_with_bits(
    &template,
    &context,
    &prompt_bits
)?;
```

### 3. **DSPy Optimizes Both**

```rust
// COPRO optimizer improves:
// 1. Template instructions
// 2. Prompt bit content
// 3. Combination strategies

let optimizer = PromptBitDSPyOptimizer::new();

// Optimize template instruction
let optimized_instruction = optimizer.optimize_instruction(
    &template.ai_signature.instruction,
    &training_examples
)?;

// Optimize prompt bits
let optimized_bits = optimizer.optimize_bits(
    &prompt_bits,
    &feedback_data
)?;

// A/B test combinations
let best_combo = optimizer.ab_test_combinations(
    &template,
    &prompt_bits,
    &test_cases
)?;
```

## Enhanced Template Format

### Before (Template Only):
```json
{
  "ai_signature": {
    "instruction": "Generate FastAPI endpoint..."
  }
}
```

### After (Template + Prompt Bits):
```json
{
  "ai_signature": {
    "instruction": "Generate FastAPI endpoint...",

    "prompt_bits_refs": [
      {
        "id": "fastapi-best-practices",
        "category": "BestPractices",
        "weight": 1.0,
        "required": true
      },
      {
        "id": "python-async-patterns",
        "category": "CodePatterns",
        "weight": 0.8,
        "required": false
      }
    ],

    "prompt_bit_assembly": {
      "strategy": "weighted_concatenation",
      "max_bits": 5,
      "auto_discover": true,
      "filters": {
        "min_confidence": 0.7,
        "categories": ["BestPractices", "Security", "Performance"]
      }
    }
  },

  "detector_signatures": {
    "dependencies": ["fastapi"],
    "auto_load_prompt_bits": true,
    "prompt_bit_triggers": [
      {
        "when": "security_level == 'high'",
        "load": ["fastapi-security-oauth2", "fastapi-rate-limiting"]
      },
      {
        "when": "performance_profile == 'high-throughput'",
        "load": ["fastapi-async-optimization", "fastapi-caching"]
      }
    ]
  }
}
```

## Example: FastAPI Template with Prompt Bits

```json
{
  "id": "python-fastapi-endpoint",
  "ai_signature": {
    "instruction": "{{base_instruction}} {{prompt_bits}}",

    "prompt_bits_refs": [
      {
        "id": "fastapi-rest-best-practices",
        "content": "Use async def for all endpoints. Return response_model types. Use HTTPException for errors. Add OpenAPI documentation with description= and summary=.",
        "trigger": "always",
        "weight": 1.0
      },
      {
        "id": "fastapi-security-patterns",
        "content": "For authentication: Use OAuth2PasswordBearer or API key dependencies. Validate tokens in dependencies. Use Depends() for dependency injection.",
        "trigger": "auth_required == true",
        "weight": 0.9
      },
      {
        "id": "pydantic-v2-validation",
        "content": "Use Pydantic v2 syntax: Field(..., description=), model_validator, ConfigDict. Use strict mode for production.",
        "trigger": "always",
        "weight": 0.8
      },
      {
        "id": "fastapi-error-handling",
        "content": "Use structured error responses. Create custom HTTPException classes. Log errors with context. Return proper status codes (400, 401, 403, 404, 500).",
        "trigger": "always",
        "weight": 0.7
      }
    ],

    "assembly_template": "
{base_instruction}

## Best Practices
{prompt_bits.BestPractices}

## Security Guidelines
{prompt_bits.Security}

## Error Handling
{prompt_bits.ErrorHandling}

## Code Style
- {tech_stack_conventions}
- {project_specific_patterns}
"
  }
}
```

## Benefits of Integration

### 1. **Composable Knowledge**
- Templates = Structure
- Prompt Bits = Knowledge fragments
- Combination = Optimal prompts

### 2. **Continuous Improvement**
- DSPy optimizes prompt bits independently
- A/B tests different combinations
- Learns from feedback

### 3. **Context-Aware Assembly**
```rust
// Low security project
let bits = ["fastapi-basic-auth"];  // Lightweight

// High security project
let bits = [
    "fastapi-oauth2-jwt",
    "fastapi-rate-limiting",
    "fastapi-input-validation",
    "fastapi-sql-injection-prevention"
];  // Comprehensive

// Template stays same, bits adapt!
```

### 4. **Multi-Language Reuse**
```
Prompt Bit: "NATS Consumer Best Practices"
├─ Used by: rust-nats-consumer.json
├─ Used by: elixir-nats-consumer.json
└─ Used by: gleam-nats-consumer.json

// Same knowledge, language-specific templates
```

## Implementation Steps

1. ✅ Templates exist (rust-fastapi.json, etc.)
2. ✅ Prompt Bits exist (prompt_engine/src/prompt_bits/)
3. ⚠️ **TODO**: Add `prompt_bits_refs` to template schema
4. ⚠️ **TODO**: Create `TemplateWithBits` assembler
5. ⚠️ **TODO**: Connect DSPy optimizer to templates
6. ⚠️ **TODO**: Add feedback loop from generated code quality

## Usage Example

```rust
// Load template
let template = registry.get("python-fastapi-endpoint")?;

// Detect context
let detection = detector.detect(project_path).await?;
let template_context = TemplateContext::from_detection(&detection);

// Load & expand prompt bits
let prompt_bits = PromptBitAssembler::new()
    .load_refs(template.ai_signature.prompt_bits_refs)
    .auto_discover(&template_context)
    .filter_by_confidence(0.7)
    .assemble()?;

// Generate enhanced prompt
let final_prompt = TemplateExpander::new()
    .expand_with_bits(&template, &template_context, &prompt_bits)?;

// Send to LLM
let code = llm.generate(&final_prompt)?;

// Collect feedback
PromptFeedbackCollector::record(
    template_id: template.id,
    prompt_bits_used: prompt_bits.ids(),
    code_quality: CodeQualityMetrics::analyze(&code),
    user_accepted: true
);

// DSPy learns and improves both template AND bits
```

## Result: Self-Improving Code Generation

```
Iteration 1: Template + Default Prompt Bits
→ Code Quality: 75%
→ DSPy learns what worked

Iteration 2: Template + Optimized Prompt Bits (COPRO)
→ Code Quality: 82%
→ Learns which bits are most effective

Iteration 3: Template + A/B Tested Combinations
→ Code Quality: 89%
→ Optimal bit combination discovered

Iteration N: Fully Optimized
→ Code Quality: 95%+
→ System generates production-ready code automatically
```

**Templates provide structure, Prompt Bits provide knowledge, DSPy optimizes both!** 🚀
