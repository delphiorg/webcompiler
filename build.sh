#!/bin/bash

# Exit on error
set -e

DEMO_DIR="webcompiler"
SOURCES_DIR="$DEMO_DIR/sources"
FILES_JSON="$DEMO_DIR/files.json"
LPR_FILE="$DEMO_DIR/webcompiler.lpr"
FPC_PATH="fpc"
PAS2JS_REPO="pas2js"

# --- Compiler Detection & Download ---

# Determine OS
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
    Linux*)     OS_TYPE=linux;; 
    Darwin*)    OS_TYPE=macos;; 
    CYGWIN*|MINGW*|MSYS*) OS_TYPE=windows;; 
    *)          OS_TYPE="unknown";;
esac

# Compiler download URLs
URL_LINUX="https://getpas2js.freepascal.org/downloads/linux/pas2js-linux-x86_64-current.zip"
URL_WINDOWS="https://getpas2js.freepascal.org/downloads/windows/pas2js-win64-x86_64-current.zip"
URL_LINUX_ARM="https://getpas2js.freepascal.org/downloads/linux/pas2js-linux-aarch64-current.zip" 
URL_MACOS_INTEL="https://getpas2js.freepascal.org/downloads/darwin/pas2js-darwin-x86_64-current.zip" 
URL_MACOS_ARM="https://getpas2js.freepascal.org/downloads/darwin/pas2js-darwin-aarch64-current.zip"

PAS2JS_BIN=""

# 1. Check environment variable
if [ -n "$PAS2JS_BIN_ENV" ]; then
    PAS2JS_BIN="$PAS2JS_BIN_ENV"
fi

# 2. Check local bin folder
if [ -z "$PAS2JS_BIN" ]; then
    if [ "$OS_TYPE" == "windows" ]; then
        if [ -f "bin/pas2js.exe" ]; then PAS2JS_BIN="bin/pas2js.exe"; fi
    else
        if [ -f "bin/pas2js" ]; then PAS2JS_BIN="bin/pas2js"; fi
    fi
fi

# 3. Check system path
if [ -z "$PAS2JS_BIN" ] && command -v pas2js &> /dev/null; then
    PAS2JS_BIN="pas2js"
fi

# 4. Download if missing
if [ -z "$PAS2JS_BIN" ]; then
    echo "Compiler not found locally or in PATH. Attempting to download..."
    
    DOWNLOAD_DIR="compiler_dist"
    mkdir -p "$DOWNLOAD_DIR"
    
    if [ "$OS_TYPE" == "linux" ]; then
        ZIP_FILE="$DOWNLOAD_DIR/pas2js.zip"
        echo "Downloading Linux compiler from $URL_LINUX..."
        curl -L -o "$ZIP_FILE" "$URL_LINUX" || wget -O "$ZIP_FILE" "$URL_LINUX"
        
        echo "Extracting..."
        unzip -q -o "$ZIP_FILE" -d "$DOWNLOAD_DIR"
        
        # Find binary
        FOUND_BIN=$(find "$DOWNLOAD_DIR" -type f -name "pas2js" | head -n 1)
        if [ -n "$FOUND_BIN" ]; then
            chmod +x "$FOUND_BIN"
            PAS2JS_BIN="$FOUND_BIN"
        fi
        
    elif [ "$OS_TYPE" == "windows" ]; then
        ZIP_FILE="$DOWNLOAD_DIR/pas2js.zip"
        echo "Downloading Windows compiler from $URL_WINDOWS..."
        curl -L -o "$ZIP_FILE" "$URL_WINDOWS" || wget -O "$ZIP_FILE" "$URL_WINDOWS"
        
        echo "Extracting..."
        unzip -q -o "$ZIP_FILE" -d "$DOWNLOAD_DIR"
        
        FOUND_BIN=$(find "$DOWNLOAD_DIR" -type f -name "pas2js.exe" | head -n 1)
        if [ -n "$FOUND_BIN" ]; then
            PAS2JS_BIN="$FOUND_BIN"
        fi
    else
        echo "Error: Auto-download not supported for OS: $OS_TYPE"
        exit 1
    fi
fi

if [ -z "$PAS2JS_BIN" ]; then
    echo "Error: Could not determine or download pas2js compiler."
    exit 1
fi

echo "==========================================