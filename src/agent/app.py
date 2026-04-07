"""BedrockAgentCore entrypoint for the GPU Spot Lotto agent."""
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent

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
