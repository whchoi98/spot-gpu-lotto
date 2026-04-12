# Sync Docs Skill

Synchronize project documentation with current code state.

## Actions

### 1. Root CLAUDE.md Sync
- Update Tech Stack, Conventions, Key Commands
- Verify commands are copy-paste ready

### 2. Module CLAUDE.md Audit
- Scan: `src/api_server/`, `src/common/`, `src/dispatcher/`, `src/price_watcher/`, `frontend/`
- Create CLAUDE.md for modules missing one
- Update existing files if out of date

### 3. Architecture Doc Sync
- Update `docs/architecture.md` to reflect current system structure
- Verify diagrams match actual component layout

### 4. ADR and Runbook Audit
- Check recent commits for undocumented decisions
- Verify runbook coverage (deploy, incident, rollback)

### 5. Report
- Output list of all changes made
- Flag stale documentation
