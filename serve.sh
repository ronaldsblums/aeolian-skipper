#!/bin/bash
# Start a local server to run the Aeolian Skipper Tool
# Usage: bash serve.sh
# Then open http://localhost:8080 in your browser
cd "$(dirname "$0")"
echo "Serving Aeolian Skipper Tool at http://localhost:8080"
echo "Press Ctrl+C to stop"
python3 -m http.server 8080
