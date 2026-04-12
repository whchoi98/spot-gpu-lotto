---
description: Execute the full test suite and report results
allowed-tools: Read, Bash(pytest:*), Bash(npx tsc:*), Bash(npm run build:*), Bash(ruff:*), Bash(mypy:*), Glob
---

# Test All

Execute the full test suite for GPU Spot Lotto.

## Step 1: Backend Tests

```bash
# Lint
cd /home/ec2-user/my-project/spot-gpu-lotto
ruff check src/

# Type check
mypy src/

# Unit tests
pytest src/tests/unit/ -v

# Integration tests (if available)
pytest src/tests/integration/ -v
```

## Step 2: Frontend Tests

```bash
cd frontend

# Type check
npx tsc --noEmit

# Build verification
npm run build
```

## Step 3: Report

Present:
- Total tests run, passed, failed, skipped
- Failed test details with file paths and error messages
- Suggest fixes for failing tests if the cause is apparent

## Error Recovery

### If test runner itself fails
```bash
# Check Python venv
source .venv/bin/activate
pip install -e ".[dev]"

# Check Node dependencies
cd frontend && npm install
```

### Common failure categories and fixes

| Failure Pattern | Likely Cause | Fix |
|---|---|---|
| "ModuleNotFoundError" | Missing dependency | `pip install -e ".[dev]"` |
| "Cannot find module" | Missing npm package | `cd frontend && npm install` |
| "Redis connection" | Redis not running | Use `fakeredis` for unit tests |
| "TS2307: Cannot find module" | Missing type declarations | `npx tsc --noEmit` to check |
