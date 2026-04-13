"""BedrockAgentCore entrypoint for the GPU Spot Lotto agent.

Architecture:
  - Job Management: httpx → API Server → Redis (single data path)
  - Infra Management: boto3/kubernetes → AWS APIs (direct access)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from bedrock_agentcore.runtime import BedrockAgentCoreApp  # noqa: E402
from strands import Agent  # noqa: E402

from agent.system_prompt import SYSTEM_PROMPT  # noqa: E402
from agent.tools_infra import (  # noqa: E402
    describe_nodepool,
    describe_redis,
    get_cost_summary,
    get_helm_status,
    list_clusters,
    list_nodes,
    list_pods,
)
from agent.tools_jobs import (  # noqa: E402
    cancel_job,
    get_job_status,
    get_prices,
    get_stats,
    list_jobs,
    submit_job,
)
from common.config import get_settings  # noqa: E402

app = BedrockAgentCoreApp()

JOB_TOOLS = [get_prices, submit_job, get_job_status, cancel_job, list_jobs, get_stats]
INFRA_TOOLS = [list_clusters, list_nodes, list_pods, describe_nodepool, get_helm_status,
               describe_redis, get_cost_summary]


@app.entrypoint
def invoke(payload, context):
    """Handle an incoming agent invocation."""
    prompt = payload.get(
        "prompt",
        "No prompt provided. Ask the user what GPU job they'd like to run.",
    )
    agent = Agent(
        model=get_settings().agent_model,
        tools=JOB_TOOLS + INFRA_TOOLS,
        system_prompt=SYSTEM_PROMPT,
    )
    result = agent(prompt)
    return {"result": result.message}


if __name__ == "__main__":
    app.run()
