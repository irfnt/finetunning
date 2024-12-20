pip install unsloth

pip install gradio

import gradio as gr
from unsloth import FastLanguageModel
from transformers import TextStreamer

# Load the model and tokenizer
model_name = "Irfantariq01/lora_model"  # Replace with your fine-tuned model name
max_seq_length = 512  # Adjust as needed

print("[INFO] Loading model...")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name=model_name,
    max_seq_length=max_seq_length,
    dtype=None,
    load_in_4bit=True,
)

# Enable faster inference
FastLanguageModel.for_inference(model)
print("[INFO] Model loaded and optimized for inference.")

# Function to generate response
def generate_code(description):
    """
    Generate Verilog or other code based on a description.

    Args:
        description (str): The natural language prompt for code generation.

    Returns:
        str: The generated code.
    """
    alpaca_prompt = (
        "Below is an instruction that describes a task. "
        "Write a response that appropriately completes the request.\n\n"
        "### Instruction:\n{description}\n\n### Response:\n"
    )

    # Format the input prompt
    prompt = alpaca_prompt.format(description=description)

    # Tokenize and move inputs to GPU
    inputs = tokenizer([prompt], return_tensors="pt").to("cuda")

    # Stream the response
    text_streamer = TextStreamer(tokenizer)
    outputs = model.generate(
        **inputs,
        streamer=text_streamer,
        max_new_tokens=512,
    )

    # Decode the generated output
    generated_code = tokenizer.decode(outputs[0], skip_special_tokens=True)
    return generated_code

# Define the Gradio Interface
iface = gr.Interface(
    fn=generate_code,
    inputs=gr.Textbox(lines=5, placeholder="Enter your description here..."),
    outputs=gr.Code(label="Generated Code"),  # Outputs as formatted code
    title="Code Generation with Small language model",
    description="Enter a description to generate Verilog or other code.",
)

# Launch the Gradio interface
if __name__ == "__main__":
    iface.launch()
