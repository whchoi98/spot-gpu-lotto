"""BedrockAgentCore entrypoint for the GPU Spot Lotto agent."""
import sys
from pathlib import Path

# AgentCore Runtime places source at /var/task/src/agent/app.py.
# Add /var/task/src to sys.path so "from agent.xxx" and "from common.xxx" resolve.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from bedrock_agentcore.runtime import BedrockAgentCoreApp  # noqa: E402
from strands import Agent  # noqa: E402

from agent.system_prompt import SYSTEM_PROMPT
from agent.tools import (
    check_spot_prices,
    get_failure_history,
    get_job_status,
    list_active_jobs,
    submit_gpu_job,
)
from common.config import get_settings

app = BedrockAgentCoreApp()

TOOLS = [check_spot_prices, submit_gpu_job, get_job_status, list_active_jobs, get_failure_history]


def create_agent() -> Agent:
    settings = get_settings()
    return Agent(
        model=settings.agent_model,
        tools=TOOLS,
        system_prompt=SYSTEM_PROMPT,
    )


@app.entrypoint
def invoke(payload, context):
    """Handle an incoming agent invocation."""
    prompt = payload.get(
        "prompt",
        "No prompt provided. Ask the user what GPU job they'd like to run.",
    )
    agent = create_agent()
    result = agent(prompt)
    return {"result": result.message}


if __name__ == "__main__":
    app.run()
