# Aider Configuration Rules

## Working Directory

When using aider, remember that its current working directory is `/Users/azmaveth/code`. 

**ALWAYS prefix file paths with `singularity_llm/`** so aider writes code in the correct directory.

## File Path Examples

**Correct:**
- `singularity_llm/lib/singularity_llm/consent_handler.ex`
- `singularity_llm/test/singularity_llm/compliance/security_compliance_test.exs`
- `singularity_llm/config/config.exs`

**Incorrect:**
- `lib/singularity_llm/consent_handler.ex` (missing singularity_llm/ prefix)
- `test/singularity_llm/compliance/security_compliance_test.exs` (missing singularity_llm/ prefix)
- `config/config.exs` (missing singularity_llm/ prefix)

## Implementation Notes

- All file paths in aider commands must include the `singularity_llm/` prefix
- This ensures files are created in the correct SingularityLLM project directory
- Verify file locations after creation to confirm proper placement
