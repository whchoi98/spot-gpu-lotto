# Product Context

## What is GPU Spot Lotto?
A system that monitors GPU Spot instance prices across multiple AWS regions in real time and dispatches workloads to the cheapest available region automatically.

## Problem
GPU compute is expensive. Spot instances offer 60-90% savings but prices fluctuate across regions and availability is unpredictable. Manual region selection is slow and suboptimal.

## Solution
- Real-time price monitoring across 3 US regions (60s polling via EC2 Spot API)
- Automatic dispatch to cheapest region with available capacity
- Spot interruption recovery with checkpoint preservation (FSx Lustre)
- Hub-and-Spoke data sync (Seoul S3 hub → FSx Lustre per region, auto-import/export)
- Dual AI agent: chat UI with approval model (Bedrock Converse) + standalone Strands agent on AgentCore Runtime

## Users
- ML engineers submitting GPU training jobs
- Platform admins managing capacity and monitoring costs
- Users interacting via natural-language chat UI (Korean/English bilingual)

## Key Workflows
1. **Job dispatch**: User submits job → queued in Redis → dispatcher picks cheapest region → Pod created on EKS
2. **Spot recovery**: Spot interruption → checkpoint saved to FSx → job rescheduled to next cheapest region
3. **Chat agent**: User chats in Agent UI → Bedrock Converse sees live prices/stats → proposes action → user approves
4. **Strands agent**: AgentCore Runtime agent → httpx → API Server for job ops, boto3 for infra ops
5. **Data sync**: Seoul S3 hub ↔ FSx Lustre per spot region (models, datasets, checkpoints, results)
