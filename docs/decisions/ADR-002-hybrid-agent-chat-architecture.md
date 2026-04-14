# ADR-002: Hybrid Agent Chat Architecture (Bedrock Converse + Strands)

## Status
Accepted

## Context
ADR-001 established a Strands agent on AgentCore Runtime with MCP Gateway for natural-language
GPU job management. However, AgentCore Runtime in PUBLIC mode cannot access VPC resources
(ElastiCache Redis), making it impossible to inject real-time system context (spot prices,
queue depth, region capacity) into the agent's prompt.

The frontend needed a chat UI where the agent sees live Redis data and proposes actions the
user can approve before execution (hybrid approval model).

## Options Considered

### Option 1: VPC-connected AgentCore Runtime
- **Pros**: Single agent architecture, reuses Strands tools
- **Cons**: AgentCore VPC support was not GA; adds network complexity; higher latency for chat

### Option 2: Proxy endpoint forwarding to AgentCore invoke
- **Pros**: Reuses the deployed agent
- **Cons**: Double-hop latency (API Server → AgentCore → MCP Gateway → API Server); cannot inject Redis context into Strands system prompt at call time

### Option 3: In-API-Server Bedrock Converse endpoint (chosen)
- **Pros**: Direct Redis access for context injection, low latency, hybrid approval model with `proposal` code blocks, simple deployment (part of existing API server)
- **Cons**: Two agent implementations to maintain, Converse endpoint lacks tool-use loop (single-turn)

## Decision
Added `POST /api/agent/chat` in the API server using Bedrock Converse API directly.
This endpoint runs alongside (not replacing) the Strands agent on AgentCore Runtime.

Design:
- **Chat endpoint** (`routes/agent.py`): Bedrock Converse with Redis context injection, hybrid approval model
- **Strands agent** (`src/agent/`): Full tool-use agent on AgentCore Runtime for standalone use
- Both use the same LLM model (`AGENT_MODEL` setting, default `global.anthropic.claude-sonnet-4-6`)
- Agent tools split: `tools_jobs.py` (httpx → API Server) and `tools_infra.py` (boto3 → AWS)

## Consequences

### Positive
- Chat UI has real-time Redis context (prices, stats, capacity) in every request
- Hybrid approval model prevents accidental job submission
- Low latency: single Bedrock API call, no MCP roundtrip
- Strands agent remains available for standalone invocation via AgentCore Runtime

### Negative
- Two agent codepaths to maintain (Converse in API server + Strands on AgentCore)
- Chat endpoint is single-turn (no tool-use loop) -- cannot execute multi-step workflows
- System prompt is duplicated between `routes/agent.py` and `src/agent/system_prompt.py`
