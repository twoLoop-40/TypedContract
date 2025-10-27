#!/bin/bash
# Build Idris2 base Docker image
# This image contains Idris2, Chez Scheme, and LaTeX
# Build this ONCE, then reuse for fast backend rebuilds

set -e

echo "Building Idris2 base image..."
echo "This will take 5-10 minutes (one-time setup)"
echo ""

cd "$(dirname "$0")/.."

docker build \
  -f docker/Dockerfile.idris2-base \
  -t typedcontract-idris2-base:latest \
  .

echo ""
echo "✅ Idris2 base image built successfully!"
echo ""
echo "Image: typedcontract-idris2-base:latest"
echo ""
echo "Next steps:"
echo "  1. Run 'docker-compose up -d backend' to start the backend"
echo "  2. Backend will build in ~30 seconds (not 10 minutes!)"
echo ""
