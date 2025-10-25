#!/usr/bin/env python3
"""Fine-tune CodeT5+ 770M on Rust and Elixir code with specialized configuration.

This script is optimized for training on Rust and Elixir code patterns,
including cross-language learning and language-specific preprocessing.

Example:
    nix develop .#llm-train
    accelerate launch ai-server/scripts/train_rust_elixir_t5.py \
        --train-file data/rust_elixir/train.jsonl \
        --eval-file data/rust_elixir/eval.jsonl \
        --output-dir runs/codet5p-770m-rust-elixir \
        --cross-language-learning
"""

from __future__ import annotations

import argparse
import json
import math
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

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
class RustElixirArgs:
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
    cross_language_learning: bool
    rust_weight: float
    elixir_weight: float


def parse_args() -> RustElixirArgs:
    parser = argparse.ArgumentParser(description="Fine-tune CodeT5+ on Rust and Elixir code")
    
    # Data arguments
    parser.add_argument("--train-file", required=True, help="Path to train JSONL")
    parser.add_argument("--eval-file", help="Path to eval JSONL")
    parser.add_argument("--output-dir", required=True, help="Directory to store adapters and logs")
    
    # Model arguments
    parser.add_argument("--base-model", default="Salesforce/codet5p-770m", help="HF model id or local path")
    parser.add_argument("--max-seq-len", type=int, default=1024, help="Maximum sequence length")
    
    # Training arguments
    parser.add_argument("--train-batch-size", type=int, default=4, help="Training batch size")
    parser.add_argument("--eval-batch-size", type=int, default=8, help="Evaluation batch size")
    parser.add_argument("--gradient-accumulation", type=int, default=8, help="Gradient accumulation steps")
    parser.add_argument("--learning-rate", type=float, default=2.0e-4, help="Learning rate")
    parser.add_argument("--weight-decay", type=float, default=0.01, help="Weight decay")
    parser.add_argument("--epochs", type=int, default=12, help="Number of training epochs")
    parser.add_argument("--warmup-steps", type=int, default=1000, help="Number of warmup steps")
    
    # LoRA arguments
    parser.add_argument("--lora-rank", type=int, default=16, help="LoRA rank")
    parser.add_argument("--lora-alpha", type=int, default=32, help="LoRA alpha")
    parser.add_argument("--lora-dropout", type=float, default=0.1, help="LoRA dropout")
    
    # Rust/Elixir specific arguments
    parser.add_argument("--cross-language-learning", action="store_true", 
                       help="Enable cross-language pattern learning")
    parser.add_argument("--rust-weight", type=float, default=1.0, 
                       help="Weight for Rust examples in loss calculation")
    parser.add_argument("--elixir-weight", type=float, default=1.0, 
                       help="Weight for Elixir examples in loss calculation")
    
    # Other arguments
    parser.add_argument("--log-every", type=int, default=10, help="Log every N steps")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    
    args = parser.parse_args()
    return RustElixirArgs(**vars(args))


def set_seed(seed: int) -> None:
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def load_datasets(args: RustElixirArgs, tokenizer: AutoTokenizer) -> Dict[str, Any]:
    """Load and preprocess datasets with Rust/Elixir specific handling."""
    data_files = {"train": args.train_file}
    if args.eval_file:
        data_files["validation"] = args.eval_file

    raw = load_dataset("json", data_files=data_files)

    def _format_rust_elixir(row: Dict[str, str]) -> Dict[str, Any]:
        instruction = row.get("instruction", "").strip()
        src = row.get("input", "").rstrip()
        tgt = row.get("output", "").rstrip()
        
        # Enhanced prompt for Rust/Elixir
        language = detect_language_from_content(tgt)
        enhanced_instruction = enhance_instruction_for_language(instruction, language)
        
        prompt = f"{enhanced_instruction}\n\nContext: {src}\n\n### Code Output"
        
        model_inputs = tokenizer(
            prompt,
            max_length=args.max_seq_len,
            truncation=True,
            padding=False,
        )
        
        with tokenizer.as_target_tokenizer():
            labels = tokenizer(
                tgt,
                max_length=args.max_seq_len,
                truncation=True,
                padding=False,
            )
        
        model_inputs["labels"] = labels["input_ids"]
        
        # Add language-specific metadata
        model_inputs["language"] = language
        model_inputs["quality_score"] = row.get("quality_score", 0.0)
        
        return model_inputs

    tokenised = raw.map(_format_rust_elixir, remove_columns=raw["train"].column_names)
    return tokenised


def detect_language_from_content(content: str) -> str:
    """Detect programming language from code content."""
    if "defmodule" in content or "def " in content or "|>" in content:
        return "elixir"
    elif "fn " in content or "struct " in content or "impl " in content:
        return "rust"
    else:
        return "unknown"


def enhance_instruction_for_language(instruction: str, language: str) -> str:
    """Enhance instruction with language-specific guidance."""
    if language == "rust":
        return f"{instruction}\n\nFollow Rust best practices: use Result/Option for error handling, implement proper error types, add documentation with ///, use pattern matching with match, and follow ownership rules."
    elif language == "elixir":
        return f"{instruction}\n\nFollow Elixir best practices: use pattern matching, implement proper error handling with {:ok, result} and {:error, reason}, add @doc documentation, use the pipe operator |> for data transformation, and follow OTP patterns."
    else:
        return instruction


def build_model(args: RustElixirArgs) -> AutoModelForSeq2SeqLM:
    """Build model with Rust/Elixir optimized configuration."""
    model = AutoModelForSeq2SeqLM.from_pretrained(
        args.base_model,
        torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32,
        device_map=None,
    )
    
    # LoRA configuration optimized for code generation
    lora_config = LoraConfig(
        task_type=TaskType.SEQ_2_SEQ_LM,
        r=args.lora_rank,
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        target_modules=["q", "k", "v", "o", "wi", "wo"],  # More modules for better adaptation
        bias="none",
    )
    
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()
    return model


def calculate_weighted_loss(logits, labels, language, rust_weight, elixir_weight):
    """Calculate weighted loss based on language."""
    # Standard cross-entropy loss
    loss_fct = torch.nn.CrossEntropyLoss(ignore_index=-100)
    loss = loss_fct(logits.view(-1, logits.size(-1)), labels.view(-1))
    
    # Apply language-specific weighting
    if language == "rust":
        return loss * rust_weight
    elif language == "elixir":
        return loss * elixir_weight
    else:
        return loss


def train() -> None:
    args = parse_args()
    accelerator = Accelerator(
        log_with=None, 
        gradient_accumulation_steps=args.gradient_accumulation
    )
    set_seed(args.seed)

    # Load tokenizer
    tokenizer = AutoTokenizer.from_pretrained(args.base_model, use_fast=False)
    tokenizer.padding_side = "right"

    # Load datasets
    datasets = load_datasets(args, tokenizer)
    data_collator = DataCollatorForSeq2Seq(
        tokenizer=tokenizer, 
        model=args.base_model, 
        pad_to_multiple_of=8
    )

    # Build model
    model = build_model(args)

    # Create data loaders
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

    # Setup optimizer and scheduler
    optimizer = AdamW(
        model.parameters(),
        lr=args.learning_rate,
        weight_decay=args.weight_decay,
    )

    num_training_steps = len(train_dl) * args.epochs // args.gradient_accumulation
    scheduler = get_cosine_schedule_with_warmup(
        optimizer,
        num_warmup_steps=args.warmup_steps,
        num_training_steps=num_training_steps,
    )

    # Prepare for training
    model, optimizer, train_dl, eval_dl, scheduler = accelerator.prepare(
        model, optimizer, train_dl, eval_dl, scheduler
    )

    # Training loop
    model.train()
    progress_bar = tqdm(range(num_training_steps), desc="Training")

    for epoch in range(args.epochs):
        for step, batch in enumerate(train_dl):
            with accelerator.accumulate(model):
                outputs = model(**batch)
                
                # Calculate weighted loss if cross-language learning is enabled
                if args.cross_language_learning and "language" in batch:
                    languages = batch["language"]
                    total_loss = 0
                    for i, lang in enumerate(languages):
                        lang_loss = calculate_weighted_loss(
                            outputs.logits[i:i+1], 
                            batch["labels"][i:i+1], 
                            lang, 
                            args.rust_weight, 
                            args.elixir_weight
                        )
                        total_loss += lang_loss
                    loss = total_loss / len(languages)
                else:
                    loss = outputs.loss

                accelerator.backward(loss)
                
                if accelerator.sync_gradients:
                    accelerator.clip_grad_norm_(model.parameters(), 1.0)
                
                optimizer.step()
                scheduler.step()
                optimizer.zero_grad()

            if accelerator.sync_gradients:
                progress_bar.update(1)
                
                if step % args.log_every == 0:
                    accelerator.print(f"Epoch {epoch}, Step {step}, Loss: {loss.item():.4f}")

        # Evaluation
        if eval_dl is not None:
            model.eval()
            eval_loss = 0
            eval_steps = 0
            
            with torch.no_grad():
                for batch in eval_dl:
                    outputs = model(**batch)
                    eval_loss += outputs.loss.item()
                    eval_steps += 1
            
            avg_eval_loss = eval_loss / eval_steps
            accelerator.print(f"Epoch {epoch}, Eval Loss: {avg_eval_loss:.4f}")
            model.train()

    # Save model
    accelerator.wait_for_everyone()
    unwrapped_model = accelerator.unwrap_model(model)
    unwrapped_model.save_pretrained(args.output_dir)
    tokenizer.save_pretrained(args.output_dir)
    
    # Save training configuration
    config = {
        "base_model": args.base_model,
        "lora_config": {
            "r": args.lora_rank,
            "lora_alpha": args.lora_alpha,
            "lora_dropout": args.lora_dropout,
        },
        "training_args": {
            "learning_rate": args.learning_rate,
            "epochs": args.epochs,
            "batch_size": args.train_batch_size,
        },
        "rust_elixir_specific": {
            "cross_language_learning": args.cross_language_learning,
            "rust_weight": args.rust_weight,
            "elixir_weight": args.elixir_weight,
        }
    }
    
    with open(os.path.join(args.output_dir, "training_config.json"), "w") as f:
        json.dump(config, f, indent=2)
    
    accelerator.print(f"Model saved to {args.output_dir}")


if __name__ == "__main__":
    train()