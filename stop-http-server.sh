#!/bin/bash
# Stop the mcpr HTTP server

echo "Stopping mcpr HTTP server..."
pkill -f "run-http-server.R"

if [ $? -eq 0 ]; then
    echo "Server stopped successfully"
else
    echo "No server process found"
fi