# Gleam/Elixir CodeT5+ Fine-tuning Guide

This checklist captures what to gather before running the training script in `ai-server/scripts/train_codet5.py`.

## Dataset schema

Store examples in JSON Lines (`.jsonl`) with the following keys:

```json
{
  "instruction": "Describe the edit – e.g. refactor, add docs.",
  "input": "Original code snippet (Gleam or Elixir).",
  "output": "Desired code after the change."
}
```

- Keep code fenced exactly as it should appear in the editor. Avoid extra indentation or shell prompts.
- For multi-file edits, stitch relevant context together in `input` and mention filenames inside the instruction.
- Recommended splits: `train.jsonl`, `eval.jsonl`, `calibration.jsonl` (manual spot checks).

## Generation of examples

1. Pull high-quality changes from your repos (e.g. `git show` of Gleam/Elixir commits).
2. Convert the diff into instruction/input/output triples.
3. Include short one-liners (formatting, rename) and larger refactors to teach scale.
4. Augment by rephrasing instructions or permuting clause order to avoid memorisation.

Aim for 40–60k training rows plus 2–3k eval rows. Keep at most ~1k tokens per field so the 1024-token window fits.

## Caches

All training caches default to `${STATE_DIR}/.cache/huggingface` (configured in `.envrc`). Override via env vars if required.

## Running training

```bash
nix develop .#llm-train
accelerate config  # first run only
accelerate launch ai-server/scripts/train_codet5.py \
  --train-file data/gleam_elixir/train.jsonl \
  --eval-file data/gleam_elixir/eval.jsonl \
  --output-dir runs/codet5p-770m-gleam-elixir
```

See the script header for full CLI options (epochs, batch sizes, LoRA rank, etc.).
