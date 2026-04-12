# Code Review Skill

Review changed code with confidence-based scoring to filter false positives.

## Review Scope

By default, review unstaged changes from `git diff`. The user may specify different files or scope.

## Review Criteria

### Project Guidelines Compliance
- Python: ruff rules (E, F, I, N, W), mypy strict, async-first Redis operations
- TypeScript: strict mode, path alias `@/`, shadcn/ui conventions
- All Redis values must handle None (`or default` pattern)
- i18n: both ko and en translations required

### Bug Detection
- Logic errors and null/undefined handling
- Race conditions in async Redis operations
- Security vulnerabilities (OWASP Top 10)
- Cross-platform issues (ARM vs AMD64)

### Code Quality
- Code duplication and unnecessary complexity
- Missing error handling at system boundaries
- Test coverage gaps

## Confidence Scoring

Rate each issue 0-100. **Only report issues with confidence >= 75.**

## Output Format

For each issue:
### [CRITICAL|IMPORTANT] <issue title> (confidence: XX)
**File:** `path/to/file.ext:line`
**Issue:** Clear description
**Fix:** Concrete code suggestion
