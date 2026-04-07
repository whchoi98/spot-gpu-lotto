# Demos Module

## Role
Interactive bash demo scripts that showcase GPU Spot Lotto features.
Each script calls real API endpoints and displays animated terminal UI.

## Scripts
- `scenario1-cost-optimized.sh` -- 5 steps: spot price scan, job submit, auto-dispatch, cost analysis, monitoring
- `scenario2-spot-recovery.sh` -- 6 steps: checkpoint job, training, spot interruption, auto-recovery, resume, cost
- `scenario3-full-lifecycle.sh` -- 7 steps: architecture, S3 upload, price scan, FSx import, training, export, summary
- `scenario4-ai-agent.sh` -- 6 steps: architecture comparison, agent price query, failure analysis, smart dispatch, MCP Gateway, summary

## Rules
- All scripts use ASCII-only characters (no Unicode symbols -- `tr` breaks multi-byte chars)
- `hr()` function uses loop, not `tr` for character repetition
- `center()` splits `local` assignment across two lines (`set -u` compatibility)
- Scripts call real endpoints: `$API/prices`, `$API/jobs`, `$API/admin/jobs`, `$API/upload/presign`
- `POST /api/jobs` returns no job_id -- must poll `GET /api/admin/jobs` to discover new job
- `GPU_LOTTO_URL` env var overrides default CloudFront URL
- `AGENTCORE_CMD` env var overrides default `.venv/bin/agentcore` for scenario4
- scenario4 uses AgentCore Runtime (agentcore invoke) and MCP Gateway
