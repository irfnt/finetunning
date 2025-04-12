import torch
from datasets import load_dataset
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    TrainingArguments,
    Trainer,
    BitsAndBytesConfig,
)

# Step 1: Load Dataset
data = load_dataset("bnadimi/PyraNet-Verilog")

# Split the dataset into train and validation sets
data = data["train"].train_test_split(test_size=0.1)
train_dataset = data["train"]
eval_dataset = data["test"]

# Step 2: Load Tokenizer and Model
model_name = "codellama/CodeLlama-7B"  # Replace with the desired CodeLlama model variant
tokenizer = AutoTokenizer.from_pretrained(model_name)

# Load the model with quantization
quantization_config = BitsAndBytesConfig(load_in_8bit=True)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    device_map="auto",
    quantization_config=quantization_config,
    torch_dtype=torch.float16,
)

# Step 3: Preprocess Dataset
def preprocess_function(examples):
    """Preprocess the dataset for the model."""
    # Create a prompt that includes both 'code' and 'description'
    prompt = f"""You are a powerful text-to-Verilog code generation model. Your job is to provide Verilog code based on the given description and context code.

### Description:
{examples["description"]}

### Context Code:
{examples["code"]}

### Generated Verilog Code:
"""
    return tokenizer(prompt, truncation=True, padding="max_length", max_length=512)

# Apply preprocessing to the dataset
encoded_train_data = train_dataset.map(preprocess_function, batched=True, remove_columns=["code", "description"])
encoded_eval_data = eval_dataset.map(preprocess_function, batched=True, remove_columns=["code", "description"])

# Step 4: Training Arguments
training_args = TrainingArguments(
    output_dir="./codellama-pyranet-finetuned",
    evaluation_strategy="steps",
    eval_steps=500,
    save_strategy="steps",
    save_steps=500,
    per_device_train_batch_size=2,
    per_device_eval_batch_size=2,
    gradient_accumulation_steps=8,
    num_train_epochs=3,
    logging_dir="./logs",
    logging_steps=100,
    learning_rate=2e-5,
    warmup_steps=500,
    weight_decay=0.01,
    save_total_limit=2,
    fp16=True,  # Enable mixed precision training
    push_to_hub=False,
    report_to="tensorboard"
)

# Step 5: Trainer Object
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=encoded_train_data,
    eval_dataset=encoded_eval_data
    data_collator=DataCollatorForSeq2Seq(tokenizer, pad_to_multiple_of=8, return_tensor="pt", padding=True)
)

# Step 6: Fine-tuning
trainer.train()

# Step 7: Save the Model
trainer.save_model("./codellama-pyranet-finetuned")
tokenizer.save_pretrained("./codellama-pyranet-finetuned")

# Step 8: Generate Code Function
def generate_code(prompt, max_length=256):
    """Generate code using the fine-tuned model."""
    model.eval()  # Set the model to evaluation mode
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
    with torch.no_grad():
        outputs = model.generate(
            inputs.input_ids,
            max_length=max_length,
            num_return_sequences=1,
            temperature=0.7,
            top_k=50,
            top_p=0.95,
            do_sample=True
        )
    return tokenizer.decode(outputs[0], skip_special_tokens=True)

# Example Usage
if __name__ == "__main__":
    prompt = "module example (input a, input b, output c);"
    generated_code = generate_code(prompt)
    print("Generated Verilog Code:")
    print(generated_code)