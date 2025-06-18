#!/bin/bash

# Test MCP protocol communication
echo "Testing MCP Server Protocol..."

# Create a test input file with MCP messages
cat > test-input.jsonl << 'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"hello","arguments":{"name":"Test"}}}
EOF

echo "Sending test messages to server..."
cat test-input.jsonl | Rscript simple-mcp-server.R 2>server-stderr.log | tee server-output.jsonl

echo -e "\n\nServer stderr output:"
cat server-stderr.log

echo -e "\n\nServer responses:"
cat server-output.jsonl | jq -c . 2>/dev/null || cat server-output.jsonl