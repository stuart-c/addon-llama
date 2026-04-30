#!/usr/bin/with-contenv bashio

# Retrieve configuration using bashio
MODEL_URL=$(bashio::config 'model_url')
CTX_SIZE=$(bashio::config 'ctx_size')
THREADS=$(bashio::config 'threads')

if [ -z "$MODEL_URL" ] || [ -z "$CTX_SIZE" ] || [ -z "$THREADS" ]; then
    bashio::log.error "Missing required configuration: model_url, ctx_size, or threads"
    bashio::exit.nok
fi

# Determine filename and paths
MODEL_NAME=$(basename "$MODEL_URL")
LOCAL_MODEL_PATH="/data/$MODEL_NAME"
LOCAL_ETAG_FILE="/data/$MODEL_NAME.etag"

bashio::log.info "Starting ik_llama.cpp server..."
bashio::log.info "Model URL: $MODEL_URL"
bashio::log.info "Local Path: $LOCAL_MODEL_PATH"

# Function to get remote ETag with improved logging and redirect support
get_remote_etag() {
    local response
    local http_code
    
    bashio::log.debug "Fetching headers from $MODEL_URL"
    # Capture headers and HTTP status code, follow redirects (-L)
    response=$(curl -sI -L -w "%{http_code}" "$MODEL_URL")
    http_code=$(echo "$response" | tail -n 1)
    
    if [ "$http_code" != "200" ]; then
        bashio::log.warning "Could not retrieve remote model metadata (HTTP $http_code)"
        return 1
    fi
    
    # Extract ETag from headers
    echo "$response" | grep -i "^etag:" | cut -d' ' -f2- | tr -d '\r\n"'
}

# Check for updates
bashio::log.info "Checking for model updates..."
REMOTE_ETAG=$(get_remote_etag || echo "")
LOCAL_ETAG=""
if [ -f "$LOCAL_ETAG_FILE" ]; then
    LOCAL_ETAG=$(cat "$LOCAL_ETAG_FILE")
fi

bashio::log.info "Remote ETag: $REMOTE_ETAG"
bashio::log.info "Local ETag: $LOCAL_ETAG"

NEEDS_DOWNLOAD=false

if ! [ -f "$LOCAL_MODEL_PATH" ]; then
    bashio::log.info "Model file not found locally. Download required."
    NEEDS_DOWNLOAD=true
elif [ -n "$REMOTE_ETAG" ] && [ "$REMOTE_ETAG" != "$LOCAL_ETAG" ]; then
    bashio::log.info "New version of model detected."
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

bashio::log.info "Starting llama-server..."

exec /app/llama-server \
  --model "$LOCAL_MODEL_PATH" \
  --host 0.0.0.0 \
  --port 8080 \
  --ctx-size "$CTX_SIZE" \
  --threads "$THREADS"
