# Refactor Skill

Refactor existing code to improve quality without changing behavior.

## Principles
- Improve structure without changing behavior
- Single Responsibility Principle (SRP)
- Remove duplicate code (DRY)
- Small, incremental steps with verification

## Process

### 1. Analysis
- Identify the target code and its tests
- Map all callers and dependencies
- Confirm test coverage exists (suggest adding tests first if not)

### 2. Plan
Present the refactoring plan:
- What will change
- What will NOT change (behavior preservation)
- Risk assessment (low/medium/high)

### 3. Execute
- Make changes in small, verifiable steps
- Run `pytest -v` after each step
- Keep commits atomic

### 4. Verify
- All existing tests pass
- No behavior changes
- Lint clean: `ruff check src/` and `mypy src/`
