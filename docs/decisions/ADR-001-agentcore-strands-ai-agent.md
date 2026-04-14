# ADR-001: Adopt Amazon Bedrock AgentCore + Strands for AI Agent

## Status
Accepted

## Context
GPU Spot Lotto's rule-based dispatcher selects the cheapest region using Redis sorted set scores.
This approach ignores failure history, spot interruption patterns, and user intent nuances.
We needed a natural-language interface for advanced job scheduling that could reason about
price trends, failure patterns, and user preferences.

## Options Considered

### Option 1: Custom LLM integration (direct Bedrock API)
- **Pros**: Full control, no framework overhead
- **Cons**: Must build tool-use loop, prompt management, deployment infra from scratch

### Option 2: LangChain / LangGraph
- **Pros**: Large ecosystem, many integrations
- **Cons**: Heavy dependency tree, abstractions add complexity for simple tool-use patterns

### Option 3: Strands Agents SDK + AgentCore Runtime
- **Pros**: Lightweight `@tool` decorator pattern, serverless deployment via `agentcore deploy`, native AWS integration
- **Cons**: Newer framework, smaller community, AgentCore Runtime PUBLIC mode cannot reach VPC resources (ElastiCache Redis)

## Decision
Adopted Strands Agents SDK for the agent framework and Amazon Bedrock AgentCore Runtime for serverless deployment.

Key design choices:
- Two tool categories, single agent: job tools (httpx → API Server) + infra tools (boto3/kubernetes → AWS APIs)
- Job tools call API Server via httpx — single data path, no duplicate Redis access logic
- `dispatch_mode` setting (`rule` | `agent`) controls whether the dispatcher uses traditional or AI logic
- Agent model: `global.anthropic.claude-sonnet-4-6` (configurable via `AGENT_MODEL` env var)
- Web chat uses Bedrock Converse API in API Server (see [ADR-002](ADR-002-hybrid-agent-chat-architecture.md))

## Consequences

### Positive
- Natural-language GPU job management (price analysis, failure-aware dispatch)
- Serverless deployment — no infra management for agent runtime
- Single data path eliminates duplicate logic — API Server is the sole data gateway

### Negative
- AgentCore Runtime in PUBLIC mode cannot access ElastiCache Redis (requires VPC config for production)
- Additional AWS cost for AgentCore Runtime invocations and Bedrock model calls
- Agent responses add latency vs. direct rule-based dispatch
