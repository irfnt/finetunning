import argparse
from transformers import AutoModelForCausalLM, AutoTokenizer

# Load the model and tokenizer
model_name = "Irfantariq01/lora_model"  # Replace with your fine-tuned model name
max_seq_length = 512  # Adjust as needed

print("[INFO] Loading model...")
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    torch_dtype="auto",  # Automatically choose precision
    device_map="auto",   # Load model on GPU if available
)

print("[INFO] Model loaded.")

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

    # Tokenize and move inputs to the device
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)

    # Generate the response
    outputs = model.generate(
        **inputs,
        max_new_tokens=512,
        temperature=0.7,  # Adjust for creativity
        top_k=50,        # Use top-k sampling
        top_p=0.95       # Use nucleus sampling
    )

    # Decode the generated output
    generated_code = tokenizer.decode(outputs[0], skip_special_tokens=True)
    return generated_code

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate Verilog or other code from a natural language description."
    )
    parser.add_argument(
        "-d", "--description", type=str, help="The description for code generation."
    )
    args = parser.parse_args()

    if args.description:
        # Generate code from the provided description
        generated_code = generate_code(args.description)
        print("\n[Generated Code]:\n")
        print(generated_code)
    else:
        # Interactive mode
        print("Entering interactive mode. Type 'exit' to quit.")
        while True:
            description = input("Enter your description (or type 'exit' to quit): ")
            if description.lower() == "exit":
                print("Exiting program.")
                break

            # Generate code
            generated_code = generate_code(description)
            print("\n[Generated Code]:\n")
            print(generated_code)

