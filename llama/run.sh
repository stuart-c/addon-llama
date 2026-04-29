#!/usr/bin/env bashio

set -x

# Retrieve configuration using bashio
MODEL_URL=$(bashio::config 'model_url')
CTX_SIZE=$(bashio::config 'ctx_size')
THREADS=$(bashio::config 'threads')

# Determine filename and paths
MODEL_NAME=$(basename "$MODEL_URL")
LOCAL_MODEL_PATH="/data/$MODEL_NAME"
LOCAL_ETAG_FILE="/data/$MODEL_NAME.etag"

bashio::log.info "Model URL: $MODEL_URL"
bashio::log.info "Local Path: $LOCAL_MODEL_PATH"

# Function to get remote ETag
get_remote_etag() {
    curl -sI "$MODEL_URL" | grep -i "^etag:" | cut -d' ' -f2- | tr -d '\r\n"'
}

# Check for updates
REMOTE_ETAG=$(get_remote_etag)
LOCAL_ETAG=""
if [ -f "$LOCAL_ETAG_FILE" ]; then
    LOCAL_ETAG=$(cat "$LOCAL_ETAG_FILE")
fi

NEEDS_DOWNLOAD=false

if ! [ -f "$LOCAL_MODEL_PATH" ]; then
    bashio::log.info "Model file not found locally."
    NEEDS_DOWNLOAD=true
elif [ -n "$REMOTE_ETAG" ] && [ "$REMOTE_ETAG" != "$LOCAL_ETAG" ]; then
    bashio::log.info "New version of model detected (Remote ETag: $REMOTE_ETAG, Local ETag: $LOCAL_ETAG)."
    NEEDS_DOWNLOAD=true
else
    bashio::log.info "Model is up to date."
fi

# Download if needed
if [ "$NEEDS_DOWNLOAD" = true ]; then
    bashio::log.info "Downloading model from $MODEL_URL..."
    if ! curl -L -f -o "$LOCAL_MODEL_PATH" "$MODEL_URL"; then
        bashio::log.error "Failed to download model from $MODEL_URL!"
        bashio::exit.nok
    fi
    
    # Store new ETag if available
    if [ -n "$REMOTE_ETAG" ]; then
        echo "$REMOTE_ETAG" > "$LOCAL_ETAG_FILE"
    fi
    bashio::log.info "Download complete."
fi

# Final check
if ! [ -f "$LOCAL_MODEL_PATH" ]; then
    bashio::log.error "Model file missing after update attempt!"
    bashio::exit.nok
fi

bashio::log.info "Starting ik_llama.cpp server..."

exec /app/llama-server \
  --model "$LOCAL_MODEL_PATH" \
  --host 0.0.0.0 \
  --port 8080 \
  --ctx-size "$CTX_SIZE" \
  --threads "$THREADS"
