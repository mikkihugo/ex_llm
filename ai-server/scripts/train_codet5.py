#!/usr/bin/env python3
"""Fine-tune CodeT5+ 770M on Gleam/Elixir edit data with LoRA.

Example:
    nix develop .#llm-train
    accelerate launch ai-server/scripts/train_codet5.py \
        --train-file data/gleam_elixir/train.jsonl \
        --eval-file data/gleam_elixir/eval.jsonl \
        --output-dir runs/codet5p-770m-gleam-elixir

This script expects JSONL rows with keys: instruction, input, output.
"""

from __future__ import annotations

import argparse
import json
import math
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional

import torch
from accelerate import Accelerator
from datasets import load_dataset
from peft import LoraConfig, TaskType, get_peft_model
from torch.optim import AdamW
from torch.utils.data import DataLoader
from tqdm.auto import tqdm
from transformers import (
    AutoModelForSeq2SeqLM,
    AutoTokenizer,
    DataCollatorForSeq2Seq,
    get_cosine_schedule_with_warmup,
)


@dataclass
class Args:
    train_file: str
    eval_file: Optional[str]
    output_dir: str
    base_model: str
    max_seq_len: int
    train_batch_size: int
    eval_batch_size: int
    gradient_accumulation: int
    learning_rate: float
    weight_decay: float
    epochs: int
    warmup_steps: int
    lora_rank: int
    lora_alpha: int
    lora_dropout: float
    log_every: int
    seed: int


def parse_args() -> Args:
    parser = argparse.ArgumentParser()
    parser.add_argument("--train-file", required=True, help="Path to train JSONL")
    parser.add_argument("--eval-file", help="Path to eval JSONL")
    parser.add_argument("--output-dir", required=True, help="Directory to store adapters and logs")
    parser.add_argument("--base-model", default="Salesforce/codet5p-770m", help="HF model id or local path")
    parser.add_argument("--max-seq-len", type=int, default=1024)
    parser.add_argument("--train-batch-size", type=int, default=2)
    parser.add_argument("--eval-batch-size", type=int, default=4)
    parser.add_argument("--gradient-accumulation", type=int, default=16)
    parser.add_argument("--learning-rate", type=float, default=3e-4)
    parser.add_argument("--weight-decay", type=float, default=0.01)
    parser.add_argument("--epochs", type=int, default=8)
    parser.add_argument("--warmup-steps", type=int, default=1000)
    parser.add_argument("--lora-rank", type=int, default=16)
    parser.add_argument("--lora-alpha", type=int, default=32)
    parser.add_argument("--lora-dropout", type=float, default=0.1)
    parser.add_argument("--log-every", type=int, default=10)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    return Args(**vars(args))


def set_seed(seed: int) -> None:
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def load_datasets(args: Args, tokenizer: AutoTokenizer) -> Dict[str, Any]:
    data_files = {"train": args.train_file}
    if args.eval_file:
        data_files["validation"] = args.eval_file

    raw = load_dataset("json", data_files=data_files)

    def _format(row: Dict[str, str]) -> Dict[str, Any]:
        instruction = row.get("instruction", "").strip()
        src = row.get("input", "").rstrip()
        tgt = row.get("output", "").rstrip()
        prompt = f"{instruction}\n\n{src}\n\n### Desired Output"
        model_inputs = tokenizer(
            prompt,
            max_length=args.max_seq_len,
            truncation=True,
        )
        with tokenizer.as_target_tokenizer():
            labels = tokenizer(
                tgt,
                max_length=args.max_seq_len,
                truncation=True,
            )
        model_inputs["labels"] = labels["input_ids"]
        return model_inputs

    tokenised = raw.map(_format, remove_columns=raw["train"].column_names)
    return tokenised


def build_model(args: Args) -> AutoModelForSeq2SeqLM:
    model = AutoModelForSeq2SeqLM.from_pretrained(
        args.base_model,
        torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32,
        device_map=None,
    )
    lora_config = LoraConfig(
        task_type=TaskType.SEQ_2_SEQ_LM,
        r=args.lora_rank,
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        target_modules=["q", "k", "v", "o"],
    )
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()
    return model


def train() -> None:
    args = parse_args()
    accelerator = Accelerator(log_with=None, gradient_accumulation_steps=args.gradient_accumulation)
    set_seed(args.seed)

    tokenizer = AutoTokenizer.from_pretrained(args.base_model, use_fast=False)
    tokenizer.padding_side = "right"

    datasets = load_datasets(args, tokenizer)
    data_collator = DataCollatorForSeq2Seq(tokenizer=tokenizer, model=args.base_model, pad_to_multiple_of=8)

    model = build_model(args)

    train_dl = DataLoader(
        datasets["train"],
        batch_size=args.train_batch_size,
        shuffle=True,
        collate_fn=data_collator,
    )

    eval_dl = None
    if "validation" in datasets:
        eval_dl = DataLoader(
            datasets["validation"],
            batch_size=args.eval_batch_size,
            shuffle=False,
            collate_fn=data_collator,
        )

    num_update_steps_per_epoch = math.ceil(len(train_dl) / args.gradient_accumulation)
    max_train_steps = num_update_steps_per_epoch * args.epochs

    optimizer = AdamW(model.parameters(), lr=args.learning_rate, weight_decay=args.weight_decay)
    lr_scheduler = get_cosine_schedule_with_warmup(
        optimizer,
        num_warmup_steps=args.warmup_steps,
        num_training_steps=max_train_steps,
    )

    model, optimizer, train_dl, eval_dl, lr_scheduler = accelerator.prepare(
        model, optimizer, train_dl, eval_dl, lr_scheduler
    )

    accelerator.print(f"Training steps: {max_train_steps}")

    global_step = 0
    for epoch in range(args.epochs):
        model.train()
        progress_bar = tqdm(range(num_update_steps_per_epoch), disable=not accelerator.is_local_main_process)
        progress_bar.set_description(f"Epoch {epoch+1}/{args.epochs}")
        total_loss = 0.0

        for step, batch in enumerate(train_dl):
            with accelerator.accumulate(model):
                outputs = model(**batch)
                loss = outputs.loss
                accelerator.backward(loss)
                optimizer.step()
                lr_scheduler.step()
                optimizer.zero_grad()
            total_loss += loss.detach().float()
            global_step += 1

            if accelerator.is_local_main_process and global_step % args.log_every == 0:
                avg_loss = (total_loss / (step + 1)).item()
                tqdm.write(json.dumps({"step": global_step, "loss": avg_loss, "lr": lr_scheduler.get_last_lr()[0]}))

            if (step + 1) % args.gradient_accumulation == 0:
                progress_bar.update(1)

        if eval_dl is not None:
            evaluate(eval_dl, model, accelerator)

        accelerator.print(f"Epoch {epoch+1} mean loss: {(total_loss / len(train_dl)).item():.4f}")

    accelerator.wait_for_everyone()
    unwrapped = accelerator.unwrap_model(model)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    unwrapped.save_pretrained(output_dir)
    tokenizer.save_pretrained(output_dir)
    accelerator.print(f"Adapters saved to {output_dir}")


def evaluate(eval_dl: DataLoader, model: AutoModelForSeq2SeqLM, accelerator: Accelerator) -> None:
    model.eval()
    losses = []
    for batch in tqdm(eval_dl, disable=not accelerator.is_local_main_process, desc="Eval"):
        with torch.no_grad():
            outputs = model(**batch)
        loss = outputs.loss
        losses.append(accelerator.gather(loss.detach()))
    if losses:
        losses = torch.cat(losses)
        perplexity = torch.exp(losses.mean())
        accelerator.print(f"Eval perplexity: {perplexity.item():.3f}")


if __name__ == "__main__":
    train()
