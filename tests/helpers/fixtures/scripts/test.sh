#!/usr/bin/env bash
# Test script for validation

echo "Hello, World!"

# This should pass shellcheck
if [[ -n "$HOME" ]]; then
    echo "Home directory exists: $HOME"
fi

exit 0