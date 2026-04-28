# ik_llama.cpp Server Addon

This addon provides a high-performance local LLM server using the `ik_llama.cpp` fork, which is optimized for ARM devices like the Raspberry Pi 5.

## Installation

1. Install this addon.
2. In the addon configuration, set the `model_url` to a direct download link for a GGUF model (e.g., from Hugging Face).
3. Adjust `ctx_size` and `threads` as needed.
4. Start the addon.

## Model Management

The addon automatically manages the model file:
- **Storage**: The model is stored internally in the addon's persistent data directory (`/data`).
- **Updates**: Every time the addon starts, it checks the `ETag` of the `model_url`. If a newer version is available, it will automatically download and replace the local file.

## Configuration

### `model_url` (Required)
A direct download URL for a GGUF model file.

### `ctx_size` (Optional)
The context size for the LLM. Default is 4096.

### `threads` (Optional)
The number of CPU threads to use for inference. Default is 4 (optimized for Raspberry Pi 5).

## Accessing the Server

The server runs on port `8080` by default. It provides an OpenAI-compatible API that can be used with integrations like `Local OpenAI LLM` or other custom components.
