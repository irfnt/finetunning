import os
import torch
from datasets import load_dataset
from transformers import (

    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    pipeline,
    logging,
    BitsAndBytesConfig
)
from trl import SFTTrainer
from peft import LoraConfig
device = torch.device("mps")
dtype = torch.float32  # or torch.float16 for reduced precision
tensor = torch.randn((10, 10), device=device, dtype=dtype)
batch_size = 2
num_workers = os.cpu_count()
epochs = 10
bf16 = True
fp16 = False
gradient_accumulation_steps = 256
context_length = 512
learning_rate = 0.0001
model_name = 'Qwen/Qwen1.5-0.5B'
out_dir = 'outputs/qwen_05b_code'
dataset = load_dataset('Irfantariq01/RTL')
full_dataset = dataset['train'].train_test_split(test_size=0.05, shuffle=True)
dataset_train = full_dataset['train']
dataset_valid = full_dataset['test']
 
print(dataset_train)
print(dataset_valid)

def preprocess_function(example):
    """
    Formatting function returning a list of samples (kind of necessary for SFT API).
    """
    text = f"### Instruction:\n{example['Instruction']}\n\n### Response:\n{example['Response']}"
    return text

if bf16:
    model = AutoModelForCausalLM.from_pretrained(model_name).to(dtype=torch.bfloat16)
else:
    model = AutoModelForCausalLM.from_pretrained(model_name)
print(model)
# Total parameters and trainable parameters.


total_params = sum(p.numel() for p in model.parameters())
print(f"{total_params:,} total parameters.")
total_trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
print(f"{total_trainable_params:,} training parameters.")
tokenizer = AutoTokenizer.from_pretrained(
    model_name, 
    trust_remote_code=True,
    use_fast=False
) 
training_args = TrainingArguments(
    output_dir=f"{out_dir}/logs",
    evaluation_strategy='epoch',
    weight_decay=0.01,
    load_best_model_at_end=True,
    per_device_train_batch_size=batch_size,
    per_device_eval_batch_size=batch_size,
    logging_strategy='epoch',
    save_strategy='epoch',
    num_train_epochs=epochs,
    save_total_limit=2,
    bf16=bf16,
    fp16=fp16,
    report_to='tensorboard',
    dataloader_num_workers=num_workers,
    gradient_accumulation_steps=gradient_accumulation_steps,
    learning_rate=learning_rate,
    lr_scheduler_type='constant',
)
trainer = SFTTrainer(
    model=model,
    train_dataset=dataset_train,
    eval_dataset=dataset_valid,
    max_seq_length=context_length,
    tokenizer=tokenizer,
    args=training_args,
    formatting_func=preprocess_function,
    packing=True
)
dataloader = trainer.get_train_dataloader()
for i, sample in enumerate(dataloader):
    print(tokenizer.decode(sample['input_ids'][0]))
    print('#'*50)
    if i == 5:
        break
history = trainer.train()
