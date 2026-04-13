# Agent Module

## Role
Strands-based AI agent deployed on AgentCore Runtime.
Provides natural-language interface for both GPU job scheduling and AWS infrastructure management.
Uses `global.anthropic.claude-sonnet-4-6` as the LLM.

## Architecture
Two tool categories, single agent:
- **Job tools**: httpx → API Server → Redis (single data path, no duplicate logic)
- **Infra tools**: boto3/kubernetes → AWS APIs directly (EKS, ElastiCache, Cost Explorer)

## Key Files
- `app.py` -- BedrockAgentCoreApp entrypoint, assembles job + infra tools
- `tools_jobs.py` -- Job management @tool functions (httpx → API Server)
- `tools_infra.py` -- Infrastructure management @tool functions (boto3 → AWS APIs)
- `system_prompt.py` -- Agent system prompt with job + infra guidelines

## Job Tools (httpx → API Server)
- `get_prices` -- Query spot prices (GET /api/prices)
- `submit_job` -- Submit GPU job (POST /api/jobs)
- `get_job_status` -- Get job status (GET /api/jobs/{job_id})
- `cancel_job` -- Cancel job (DELETE /api/jobs/{job_id})
- `list_jobs` -- List active jobs (GET /api/admin/jobs)
- `get_stats` -- System statistics (GET /api/admin/stats)

## Infra Tools (boto3/kubernetes → AWS APIs)
- `list_clusters` -- All 4 EKS clusters status (boto3 eks)
- `list_nodes` -- Nodes in a cluster (kubernetes API)
- `list_pods` -- Pods in a namespace (kubernetes API)
- `describe_nodepool` -- Karpenter NodePool status (kubernetes CRD)
- `get_helm_status` -- Helm release status (helm CLI)
- `describe_redis` -- ElastiCache Redis status (boto3 elasticache)
- `get_cost_summary` -- AWS cost breakdown (boto3 cost explorer)

## Rules
- Model: `global.anthropic.claude-sonnet-4-6` (configurable via AGENT_MODEL env var)
- API Server URL: configured via API_SERVER_URL env var
- Job tools never access Redis directly — all operations go through API Server
- Infra tools use boto3 with AgentCore execution role IAM permissions
- The agent responds in the same language as the user (Korean/English)
