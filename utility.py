import argparse
from transformers import AutoModelForCausalLM, AutoTokenizer, TextStreamer

# Load the model and tokenizer for the pre-trained CodeLlama model
model_name = "facebook/codellama-7b"  # Replace with your desired CodeLlama model

print("[INFO] Loading model...")
# Load the pre-trained model and tokenizer
model = AutoModelForCausalLM.from_pretrained(model_name, device_map="auto", torch_dtype="auto")
tokenizer = AutoTokenizer.from_pretrained(model_name)

print("[INFO] Model loaded and ready for inference.")

# Function to generate code
def generate_code(description):
    """
    Generate code based on a natural language description using the pre-trained CodeLlama model.

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

    # Tokenize the prompt and move inputs to GPU (if available)
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

# Main function with argparse
def main():
    parser = argparse.ArgumentParser(description="Generate code using the pre-trained CodeLlama model.")
    parser.add_argument(
        "--description",
        type=str,
        required=True,
        help="Enter the natural language description for code generation.",
    )
    args = parser.parse_args()

    # Generate code based on the input description
    print("[INFO] Generating code...")
    result = generate_code(args.description)
    print("\n[Generated Code]:\n")
    print(result)

if __name__ == "__main__":
    main()
