#!/bin/bash
# Test Idris2 MCP Server with MCP Inspector

echo "🔍 Starting MCP Inspector for Idris2 MCP Server"
echo "================================================"
echo ""
echo "This will launch a web interface at http://localhost:5173"
echo "You can test all MCP tools and resources interactively."
echo ""
echo "Press Ctrl+C to stop the server."
echo ""

cd "$(dirname "$0")"

# Run MCP Inspector
npx @modelcontextprotocol/inspector python server.py
