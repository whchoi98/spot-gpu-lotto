# Agent Module

## Role
Strands-based AI agent deployed on AgentCore Runtime.
Provides natural-language interface for GPU Spot job scheduling.
Uses `global.anthropic.claude-sonnet-4-6` as the LLM.

## Key Files
- `app.py` -- BedrockAgentCoreApp entrypoint, creates Strands Agent
- `tools.py` -- @tool functions: check_spot_prices, submit_gpu_job, get_job_status, list_active_jobs, get_failure_history
- `system_prompt.py` -- Agent system prompt with GPU instance mapping and decision guidelines

## Architecture
- Each tool has an `_impl` async function (testable with fakeredis) and a sync `@tool` wrapper
- `_impl` functions take a Redis connection as first argument for dependency injection in tests
- `@tool` wrappers resolve Redis via `get_redis()` at call time

## Rules
- Model is fixed to `global.anthropic.claude-sonnet-4-6` (configurable via AGENT_MODEL env var)
- `dispatch_mode` setting controls whether the regular dispatcher uses rule-based or agent logic
- Tools return JSON strings (Strands convention)
- The agent responds in the same language as the user (Korean/English)
