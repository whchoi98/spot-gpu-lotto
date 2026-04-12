#!/bin/bash
# Project setup script for new developers.
# Usage: bash scripts/setup.sh

set -e

echo "=== GPU Spot Lotto — Project Setup ==="

# Check prerequisites
command -v git >/dev/null 2>&1 || { echo "ERROR: git is required"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "ERROR: node is required"; exit 1; }

# Backend setup
echo "Installing Python dependencies..."
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

# Frontend setup
echo "Installing Node.js dependencies..."
cd frontend
npm install
cd ..

# Setup environment
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "IMPORTANT: Edit .env with your actual values"
fi

# Setup Claude hooks
if [ -f ".claude/hooks/check-doc-sync.sh" ]; then
    chmod +x .claude/hooks/*.sh
    echo "Claude hooks configured"
fi

# Install Git hooks
if [ -d ".git" ] && [ -f "scripts/install-hooks.sh" ]; then
    bash scripts/install-hooks.sh
fi

echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Edit .env with your configuration"
echo "  2. Read CLAUDE.md for project conventions"
echo "  3. Read docs/onboarding.md for development workflow"
echo "  4. Run: source .venv/bin/activate && uvicorn api_server.main:app --port 8000"
echo "  5. Run: cd frontend && npm run dev"
