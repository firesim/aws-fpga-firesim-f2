#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create venv if it doesn't exist
if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo "Creating venv..."
    python3 -m venv "$SCRIPT_DIR/venv"
fi

# Install jupyter if not already installed
if [ ! -f "$SCRIPT_DIR/venv/bin/jupyter" ]; then
    echo "Installing jupyter..."
    "$SCRIPT_DIR/venv/bin/pip" install jupyter ipywidgets
fi

# Add FPGA cython bindings to Python path so notebooks can import them
# This creates a .pth file that tells Python where to find the fpga bindings module
PYTHON_VER=$("$SCRIPT_DIR/venv/bin/python3" -c "import sys; print(f'python{sys.version_info.major}.{sys.version_info.minor}')")
BINDINGS_PATH="$SCRIPT_DIR/../userspace/cython_bindings"
PTH_FILE="$SCRIPT_DIR/venv/lib/$PYTHON_VER/site-packages/fpga-bindings.pth"

if [ ! -f "$PTH_FILE" ]; then
    echo "Setting up FPGA bindings path..."
    echo "$BINDINGS_PATH" > "$PTH_FILE"
fi

echo "Starting Jupyter notebook server..."
cd "$SCRIPT_DIR"
sudo -E "$SCRIPT_DIR/venv/bin/jupyter" notebook --no-browser --port=8888 --allow-root
