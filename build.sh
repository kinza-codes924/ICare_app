#!/bin/bash

echo "=== Flutter Build Script ==="

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found. Installing..."

    if [ ! -d "/tmp/flutter" ]; then
        echo "Cloning Flutter repository..."

        # Retry git clone up to 3 times with delay
        MAX_RETRIES=3
        RETRY_DELAY=10
        SUCCESS=false

        for i in $(seq 1 $MAX_RETRIES); do
            echo "Attempt $i of $MAX_RETRIES..."
            git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter
            if [ $? -eq 0 ]; then
                SUCCESS=true
                echo "Flutter cloned successfully on attempt $i"
                break
            else
                echo "Clone attempt $i failed."
                rm -rf /tmp/flutter
                if [ $i -lt $MAX_RETRIES ]; then
                    echo "Waiting ${RETRY_DELAY}s before retry..."
                    sleep $RETRY_DELAY
                    RETRY_DELAY=$((RETRY_DELAY * 2))  # exponential backoff
                fi
            fi
        done

        if [ "$SUCCESS" = false ]; then
            echo "ERROR: Failed to clone Flutter after $MAX_RETRIES attempts"
            exit 1
        fi
    else
        echo "Flutter directory already exists, skipping clone."
    fi

    # Add Flutter to PATH
    export PATH="$PATH:/tmp/flutter/bin"

    # Configure Flutter
    echo "Configuring Flutter..."
    flutter config --no-analytics

    # Precache web
    echo "Precaching Flutter web..."
    flutter precache --web
fi

# Ensure PATH includes Flutter
export PATH="$PATH:/tmp/flutter/bin"

# Verify Flutter is working
echo "Verifying Flutter installation..."
flutter --version
if [ $? -ne 0 ]; then
    echo "ERROR: Flutter verification failed"
    exit 1
fi

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "ERROR: flutter pub get failed"
    exit 1
fi

# Build for web
echo "Building Flutter web app..."
flutter build web --release
if [ $? -ne 0 ]; then
    echo "ERROR: flutter build web failed"
    exit 1
fi

echo "=== Build Complete Successfully ==="
exit 0
