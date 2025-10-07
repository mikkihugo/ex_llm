#!/usr/bin/env python3
"""Lightweight sanity check for a fine-tuned CodeT5+ adapter.

Usage:
    nix develop .#llm-train
    python ai-server/scripts/eval_codet5.py \
        --adapter runs/codet5p-770m-gleam-elixir \
        --examples data/gleam_elixir/calibration.jsonl

The examples file should follow the same schema used for training.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, Iterable

import torch
from peft import PeftModel
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--adapter", required=True, help="Directory containing LoRA adapter + tokenizer")
    parser.add_argument("--base-model", default="Salesforce/codet5p-770m")
    parser.add_argument("--examples", required=True, help="Calibration JSONL path")
    parser.add_argument("--max-seq-len", type=int, default=1024)
    parser.add_argument("--num-examples", type=int, default=5, help="Limit for quick spot checks")
    parser.add_argument("--temperature", type=float, default=0.0)
    parser.add_argument("--top-p", type=float, default=0.95)
    parser.add_argument("--max-new-tokens", type=int, default=512)
    return parser.parse_args()


def stream_examples(path: Path, limit: int) -> Iterable[Dict[str, str]]:
    with path.open() as handle:
        for idx, line in enumerate(handle):
            if limit and idx >= limit:
                break
            yield json.loads(line)


def main() -> None:
    args = parse_args()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    tokenizer = AutoTokenizer.from_pretrained(args.base_model, use_fast=False)
    base = AutoModelForSeq2SeqLM.from_pretrained(args.base_model, torch_dtype=torch.float16 if device.type == "cuda" else torch.float32)
    model = PeftModel.from_pretrained(base, args.adapter)
    model.to(device)
    model.eval()

    examples = list(stream_examples(Path(args.examples), args.num_examples))
    for idx, sample in enumerate(examples, 1):
        instruction = sample.get("instruction", "").strip()
        source = sample.get("input", "").strip()
        expected = sample.get("output", "").strip()
        prompt = f"{instruction}\n\n{source}\n\n### Desired Output"

        inputs = tokenizer(prompt, return_tensors="pt", truncation=True, max_length=args.max_seq_len).to(device)
        with torch.no_grad():
            generated = model.generate(
                **inputs,
                do_sample=args.temperature > 0,
                temperature=args.temperature,
                top_p=args.top_p,
                max_new_tokens=args.max_new_tokens,
            )
        text = tokenizer.decode(generated[0], skip_special_tokens=True)

        print(f"Example {idx}")
        print("Instruction:\n", instruction)
        print("Input:\n", source)
        print("Expected:\n", expected)
        print("Model:\n", text)
        print("-" * 80)


if __name__ == "__main__":
    main()
