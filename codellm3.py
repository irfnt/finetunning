# -*- coding: utf-8 -*-
"""Untitled93.ipynb

Automatically generated by Colab.

Original file is located at
    https://colab.research.google.com/drive/1x6iiiEZkp7bh-DHGWsbVyZgDUmUbdAUf
"""

from google.colab import drive
drive.mount('/content/drive')

!pip install -r '/content/drive/MyDrive/requirements.txt'

!pip install bitsandbytes

from datetime import datetime
import os
import torch
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    TrainingArguments,
    Trainer,
    DataCollatorForSeq2Seq,
    BitsAndBytesConfig,
)
from datasets import load_dataset
from peft import (
    LoraConfig,
    get_peft_model,
    prepare_model_for_kbit_training,
    set_peft_model_state_dict,
    PeftModel,
)

# Load dataset
dataset = load_dataset("bnadimi/PyraNet-Verilog", split="train")
split_dataset = dataset.train_test_split(test_size=0.1)
train_dataset = split_dataset["train"]
eval_dataset = split_dataset["test"]

# Print a sample for verification
print(train_dataset[2])

# Load model and tokenizer
base_model = "codellama/CodeLlama-7b-hf"
model = AutoModelForCausalLM.from_pretrained(
    base_model,
    trust_remote_code=True,
    load_in_8bit=True,
    torch_dtype=torch.float16,
    device_map="auto",
)
tokenizer = AutoTokenizer.from_pretrained(base_model)

# Test model with an evaluation prompt
eval_prompt = """You are a powerful text-to-verilog code generation model. Your job is to provide verilog code. You are given a description to generate the verilog code.

You must output the code that answers the question.
### description:
defines a module that implements a 16-bit NOT gate. It takes a 16-bit input vector `in` and produces a 16-bit output vector `out`, where each bit of `out` is the logical negation (bitwise NOT) of the corresponding bit

### code:
"""
model_input = tokenizer(eval_prompt, return_tensors="pt").to("cuda")
model.eval()
with torch.no_grad():
    generated = model.generate(**model_input, max_new_tokens=100)
    print(tokenizer.decode(generated[0], skip_special_tokens=True))

# Configure tokenizer
tokenizer.add_eos_token = True
tokenizer.pad_token_id = 0
tokenizer.padding_side = "left"

# Tokenization function
def tokenize(prompt):
    result = tokenizer(
        prompt,
        truncation=True,
        max_length=512,
        padding=False,
        return_tensors=None,
    )
    result["labels"] = result["input_ids"].copy()
    return result

def generate_and_tokenize_prompt(data_point):
    full_prompt = f"""You are a powerful text-to-verilog code generation model. Your job is to provide verilog code. You are given a description to generate the verilog code.

You must output the verilog code for given description.

### Input:
{data_point["description"]}

### Context:
{data_point["code"]}
"""
    return tokenize(full_prompt)

# Tokenize datasets
tokenized_train_dataset = train_dataset.map(generate_and_tokenize_prompt)
tokenized_val_dataset = eval_dataset.map(generate_and_tokenize_prompt)

# Prepare model for LoRA fine-tuning
model = prepare_model_for_kbit_training(model)

lora_config = LoraConfig(
    r=16,
    lora_alpha=16,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM",
)
model = get_peft_model(model, lora_config)

# Resume from checkpoint if specified
resume_from_checkpoint = ""  # specify the checkpoint path if resuming
if resume_from_checkpoint and os.path.exists(resume_from_checkpoint):
    print(f"Loading checkpoint from {resume_from_checkpoint}")
    adapter_weights = torch.load(resume_from_checkpoint)
    set_peft_model_state_dict(model, adapter_weights)

# Set up Weights and Biases for tracking
wandb_project = "sql-try2-coder"
if wandb_project:
    os.environ["WANDB_PROJECT"] = wandb_project

if torch.cuda.device_count() > 1:
    model.is_parallelizable = True
    model.model_parallel = True

# Training arguments
batch_size = 128
per_device_train_batch_size = 32
gradient_accumulation_steps = batch_size // per_device_train_batch_size
output_dir = "verilog-code-llama"

training_args = TrainingArguments(
    per_device_train_batch_size=per_device_train_batch_size,
    gradient_accumulation_steps=gradient_accumulation_steps,
    warmup_steps=100,
    max_steps=10,
    learning_rate=2e-4,
    fp16=True,
    logging_steps=10,
    optim="adamw_torch",
    evaluation_strategy="steps",
    save_strategy="steps",
    eval_steps=20,
    save_steps=20,
    output_dir=output_dir,
    load_best_model_at_end=False,
    group_by_length=True,
    report_to="wandb",
    run_name=f"codellama-{datetime.now().strftime('%Y-%m-%d-%H-%M')}",
)

# Trainer setup
trainer = Trainer(
    model=model,
    train_dataset=tokenized_train_dataset,
    eval_dataset=tokenized_val_dataset,
    args=training_args,
    data_collator=DataCollatorForSeq2Seq(
        tokenizer, pad_to_multiple_of=8, return_tensors="pt", padding=True
    ),
)

# Train model
trainer.train()

# Load final checkpoint
model = AutoModelForCausalLM.from_pretrained(
    base_model,
    load_in_8bit=True,
    torch_dtype=torch.float16,
    device_map="auto",
)
tokenizer = AutoTokenizer.from_pretrained(base_model)
model = PeftModel.from_pretrained(model, output_dir)

# Test model post-training
model_input = tokenizer(eval_prompt, return_tensors="pt").to("cuda")
model.eval()
with torch.no_grad():
    generated = model.generate(**model_input, max_new_tokens=100)
    print(tokenizer.decode(generated[0], skip_special_tokens=True))