# Product Context

## What is GPU Spot Lotto?
A system that monitors GPU Spot instance prices across multiple AWS regions in real time and dispatches workloads to the cheapest available region automatically.

## Problem
GPU compute is expensive. Spot instances offer 60-90% savings but prices fluctuate across regions and availability is unpredictable. Manual region selection is slow and suboptimal.

## Solution
- Real-time price monitoring across 3 US regions (60s polling)
- Automatic dispatch to cheapest region with available capacity
- Spot interruption recovery with checkpoint preservation
- Hub-and-Spoke data sync (Seoul S3 → FSx Lustre per region)
- Dual AI agent: chat UI with approval model + standalone Strands agent on AgentCore

## Users
- ML engineers submitting GPU training jobs
- Platform admins managing capacity and monitoring costs
- External AI agents via MCP Gateway
- Users interacting via natural-language chat UI

## Key Workflows
1. User submits job → queued in Redis → dispatcher picks cheapest region → Pod created on EKS
2. Spot interruption → checkpoint saved → job rescheduled to next cheapest region
3. User chats in Agent UI → Bedrock Converse sees live prices/stats → proposes action → user approves
4. External agent calls AgentCore Gateway (MCP) → Strands agent → httpx → API Server
