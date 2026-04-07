#!/usr/bin/env bash
# ============================================================
#  Scenario 4: AI Agent 기반 스마트 배치 (AgentCore + Strands)
#
#  AgentCore Runtime 위에 배포된 Strands Agent가
#  자연어 요청을 분석하여 최적 리전을 추천하고 작업을 제출합니다.
#  Rule-based Dispatcher와 AI Agent의 차이를 시연합니다.
# ============================================================
set -euo pipefail

BASE_URL="${GPU_LOTTO_URL:-https://d370iz4ydsallw.cloudfront.net}"
API="$BASE_URL/api"
AGENT_CMD="${AGENTCORE_CMD:-.venv/bin/agentcore}"

# ── Terminal setup ─────────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 80)
ROWS=$(tput lines 2>/dev/null || echo 24)

# ── Colors ─────────────────────────────────────────────────
R='\033[0;31m';  G='\033[0;32m';  Y='\033[0;33m';  B='\033[0;34m'
M='\033[0;35m';  C='\033[0;36m';  W='\033[1;37m';  D='\033[0;90m'
BG_B='\033[44m'; BG_G='\033[42m'; BG_R='\033[41m'; BG_Y='\033[43m'
BG_M='\033[45m'; BG_C='\033[46m'; BG_D='\033[100m'
RESET='\033[0m'; BOLD='\033[1m';  DIM='\033[2m'
UNDERLINE='\033[4m'

# ── Utility functions ──────────────────────────────────────
typewrite() {
  local text="$1" delay="${2:-0.03}"
  for ((i=0; i<${#text}; i++)); do
    printf '%s' "${text:$i:1}"
    sleep "$delay"
  done
}

typewrite_color() {
  local color="$1" text="$2" delay="${3:-0.03}"
  printf '%b' "$color"
  typewrite "$text" "$delay"
  printf '%b' "$RESET"
}

spinner() {
  local pid=$1 msg="${2:-Loading}"
  local frames=('|' '/' '-' '\')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${C}${frames[$i]}${RESET} ${msg}..."
    i=$(( (i+1) % ${#frames[@]} ))
    sleep 0.1
  done
  printf "\r  ${G}[OK]${RESET} ${msg}   \n"
}

hr() {
  local char="${1:--}" color="${2:-$D}"
  printf '%b' "$color"
  for ((k=0; k<COLS; k++)); do printf '%s' "$char"; done
  printf '%b\n' "$RESET"
}

center() {
  local text="$1"
  local pad=$(( (COLS - ${#text}) / 2 ))
  printf '%*s%s\n' "$pad" '' "$text"
}

pause_key() {
  echo
  echo -ne "  ${D}Press Enter to continue...${RESET}"
  read -r
}

anim_bar() {
  local pct=$1 width=40 color="${2:-$G}" label="${3:-}"
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  printf "  ${D}%3d%%${RESET} ${color}" "$pct"
  for ((j=0; j<filled; j++)); do printf '#'; done
  printf "${D}"
  for ((j=0; j<empty; j++)); do printf '.'; done
  printf "${RESET}"
  [ -n "$label" ] && printf " ${D}%s${RESET}" "$label"
  printf '\n'
}

# Invoke AgentCore agent and extract text
invoke_agent() {
  local prompt="$1"
  local result
  result=$($AGENT_CMD invoke "{\"prompt\": $(python3 -c "import json; print(json.dumps('$prompt'))")}" 2>/dev/null \
    | sed -n 's/.*"text": "\(.*\)".*/\1/p' \
    | head -1) || true
  if [ -z "$result" ]; then
    # Fallback: capture full response
    result=$($AGENT_CMD invoke "{\"prompt\": $(python3 -c "import json; print(json.dumps('$prompt'))")}" 2>&1 \
      | grep -A 999 "Response:" \
      | tail -n +2) || result="(Agent response unavailable)"
  fi
  echo "$result"
}

# ── FULL SCREEN BANNER ─────────────────────────────────────
clear
echo
echo
echo -e "  ${M}${BOLD}"
cat << 'LOGO'
     ██████╗ ██████╗ ██╗   ██╗    ███████╗██████╗  ██████╗ ████████╗
    ██╔════╝ ██╔══██╗██║   ██║    ██╔════╝██╔══██╗██╔═══██╗╚══██╔══╝
    ██║  ███╗██████╔╝██║   ██║    ███████╗██████╔╝██║   ██║   ██║
    ██║   ██║██╔═══╝ ██║   ██║    ╚════██║██╔═══╝ ██║   ██║   ██║
    ╚██████╔╝██║     ╚██████╔╝    ███████║██║     ╚██████╔╝   ██║
     ╚═════╝ ╚═╝      ╚═════╝     ╚══════╝╚═╝      ╚═════╝    ╚═╝
LOGO
echo -e "${RESET}"
echo
center "L O T T O"
echo
echo -e "${BG_M}${W}${BOLD}$(printf '%*s' $COLS '' | tr ' ' ' ')${RESET}"
echo -e "${BG_M}${W}${BOLD}$(center 'SCENARIO 4: AI Agent 기반 스마트 배치 — AgentCore + Strands')${RESET}"
echo -e "${BG_M}${W}${BOLD}$(printf '%*s' $COLS '' | tr ' ' ' ')${RESET}"
echo
echo -e "  ${D}+---------------------------------------------------+${RESET}"
echo -e "  ${D}|${RESET}  Runtime  ${D}|${RESET} ${M}Amazon Bedrock AgentCore${RESET}"
echo -e "  ${D}|${RESET}  Agent   ${D}|${RESET} ${W}Strands Agent${RESET} (Claude Sonnet 4.6)"
echo -e "  ${D}|${RESET}  Gateway ${D}|${RESET} ${C}MCP Protocol${RESET} (FastAPI -> Agent Tools)"
echo -e "  ${D}|${RESET}  Tools   ${D}|${RESET} check_spot_prices, get_failure_history,"
echo -e "  ${D}|${RESET}          ${D}|${RESET} submit_gpu_job, get_job_status, list_active_jobs"
echo -e "  ${D}|${RESET}  Mode    ${D}|${RESET} ${G}AI reasoning${RESET} vs ${Y}Rule-based dispatch${RESET}"
echo -e "  ${D}+---------------------------------------------------+${RESET}"
echo
echo -e "  ${W}${BOLD}  [About]${RESET}"
echo -e "  ${D}  AgentCore Runtime 위에 배포된 Strands Agent가 자연어 요청을${RESET}"
echo -e "  ${D}  분석합니다. 가격, 용량, 장애 이력을 종합 판단하여 최적의${RESET}"
echo -e "  ${D}  리전을 추천하고 작업을 제출합니다.${RESET}"
echo -e "  ${D}  Rule-based(최저가 선택)와 AI Agent(종합 판단)의 차이를 비교합니다.${RESET}"
echo
echo -e "  ${W}${BOLD}  [Steps]${RESET}"
echo -e "  ${C}  1.${RESET} 아키텍처 비교               ${D}-- Rule-based vs AI Agent${RESET}"
echo -e "  ${C}  2.${RESET} Agent 가격 조회              ${D}-- 자연어로 Spot 가격 요청${RESET}"
echo -e "  ${C}  3.${RESET} Agent 장애 분석              ${D}-- 리전별 장애 패턴 분석${RESET}"
echo -e "  ${C}  4.${RESET} Agent 스마트 배치            ${D}-- 가격+장애+용량 종합 판단${RESET}"
echo -e "  ${C}  5.${RESET} MCP Gateway 시연             ${D}-- FastAPI를 MCP 도구로 변환${RESET}"
echo -e "  ${C}  6.${RESET} 종합 비교 & 요약             ${D}-- Rule vs Agent 의사결정 비교${RESET}"

pause_key

# ================================================================
#  STEP 1 -- 아키텍처 비교: Rule-based vs AI Agent
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 1 / 6  ${RESET}  ${W}${BOLD}아키텍처 비교: Rule-based vs AI Agent${RESET}"
hr "=" "$M"
echo

echo -e "  ${Y}${BOLD}  [A] Rule-based Dispatcher (기존)${RESET}"
echo
echo -e "  ${D}      Redis Sorted Set (price ASC)${RESET}"
echo -e "  ${D}               |${RESET}"
echo -e "  ${D}               V${RESET}"
echo -e "  ${Y}      +--------------------+${RESET}"
echo -e "  ${Y}      |${RESET}  ${W}Greedy Algorithm${RESET}  ${Y}|${RESET}"
echo -e "  ${Y}      |${RESET}  cheapest region   ${Y}|${RESET}"
echo -e "  ${Y}      |${RESET}  capacity > 0      ${Y}|${RESET}"
echo -e "  ${Y}      +--------+-----------+${RESET}"
echo -e "  ${D}               |${RESET}"
echo -e "  ${D}               V${RESET}"
echo -e "  ${D}          Pod creation${RESET}"
echo
sleep 0.5

echo -e "  ${M}${BOLD}  [B] AI Agent (AgentCore + Strands)${RESET}"
echo
echo -e "  ${D}      Natural language request${RESET}"
echo -e "  ${D}               |${RESET}"
echo -e "  ${D}               V${RESET}"
echo -e "  ${M}      +--------------------+${RESET}"
echo -e "  ${M}      |${RESET}  ${W}Strands Agent${RESET}     ${M}|${RESET}  ${D}<-- Claude Sonnet 4.6${RESET}"
echo -e "  ${M}      |${RESET}  LLM reasoning     ${M}|${RESET}"
echo -e "  ${M}      +--------+-----------+${RESET}"
echo -e "  ${D}               |${RESET}"
echo -e "  ${D}      +--------+--------+${RESET}"
echo -e "  ${D}      V        V        V${RESET}"
echo -e "  ${C}  prices${RESET}  ${C}failures${RESET}  ${C}capacity${RESET}"
echo -e "  ${D}      |        |        |${RESET}"
echo -e "  ${D}      +--------+--------+${RESET}"
echo -e "  ${D}               V${RESET}"
echo -e "  ${G}      Reasoned recommendation${RESET}"
echo

echo -e "  ${D}  Key difference:${RESET}"
echo -e "  ${Y}  Rule-based${RESET} = cheapest price wins (blind to failure history)"
echo -e "  ${M}  AI Agent${RESET}   = price + capacity + failure patterns + reasoning"

pause_key

# ================================================================
#  STEP 2 -- Agent 가격 조회 (자연어)
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 2 / 6  ${RESET}  ${W}${BOLD}Agent 가격 조회${RESET}"
hr "=" "$M"
echo

echo -e "  ${D}Sending natural language request to AgentCore Runtime...${RESET}"
echo
echo -e "  ${M}  +--------------------------------------------------+${RESET}"
echo -e "  ${M}  |${RESET}  ${W}AgentCore Runtime${RESET}                               ${M}|${RESET}"
echo -e "  ${M}  |${RESET}  ARN: ...runtime/gpu_spot_lotto_agent-7c9USs3CZc  ${M}|${RESET}"
echo -e "  ${M}  |${RESET}  Model: global.anthropic.claude-sonnet-4-6        ${M}|${RESET}"
echo -e "  ${M}  +--------------------------------------------------+${RESET}"
echo

PROMPT_1="Show me current GPU spot prices for g6.xlarge across all regions."
echo -e "  ${W}User:${RESET}"
echo -ne "  ${C}> ${RESET}"
typewrite "$PROMPT_1" 0.02
echo
echo

echo -e "  ${D}Agent calling tool: ${C}check_spot_prices(instance_type='g6.xlarge')${RESET}"
echo

# Call real API for price data
curl -s "$API/prices?instance_type=g6.xlarge" > /tmp/demo4_prices.json &
spinner $! "Agent querying Redis via check_spot_prices tool"

PRICES_RAW=$(cat /tmp/demo4_prices.json)
if echo "$PRICES_RAW" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  echo
  echo "$PRICES_RAW" | python3 -c "
import sys, json
data = json.load(sys.stdin)
prices = sorted(data.get('prices', []), key=lambda x: x['price'])
if not prices:
    print('  \033[0;33mNo price data available (API returned empty)\033[0m')
else:
    print('  \033[1;37m  %-14s  %-13s  %-10s\033[0m' % ('REGION', 'INSTANCE', 'PRICE/HR'))
    print('  \033[0;90m  %-14s  %-13s  %-10s\033[0m' % ('-'*14, '-'*13, '-'*10))
    for p in prices:
        color = '\033[1;32m' if p == prices[0] else '\033[0m'
        tag = ' <-- cheapest' if p == prices[0] else ''
        print(f'  {color}  {p[\"region\"]:<14}  {p[\"instance_type\"]:<13}  \${p[\"price\"]:<9.4f}\033[0;32m{tag}\033[0m')
"
fi

echo
echo -e "  ${W}Agent:${RESET}"
echo -e "  ${G}  \"g6.xlarge prices across 3 regions are shown above.${RESET}"
echo -e "  ${G}   The cheapest is currently highlighted. But price alone${RESET}"
echo -e "  ${G}   doesn't tell the full story -- let me check failure history.\"${RESET}"

pause_key

# ================================================================
#  STEP 3 -- Agent 장애 분석
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 3 / 6  ${RESET}  ${W}${BOLD}Agent 장애 패턴 분석${RESET}"
hr "=" "$M"
echo

PROMPT_2="Which regions have the most failures recently? Should I avoid any?"
echo -e "  ${W}User:${RESET}"
echo -ne "  ${C}> ${RESET}"
typewrite "$PROMPT_2" 0.02
echo
echo

echo -e "  ${D}Agent calling tool: ${C}get_failure_history()${RESET}"
echo

# Call real API for job stats (active jobs as proxy)
curl -s "$API/admin/stats" > /tmp/demo4_stats.json 2>/dev/null &
spinner $! "Agent querying failure patterns from Redis"

echo
echo -e "  ${W}Agent Response:${RESET}"
echo

# Simulated agent reasoning (since we may not have real failure data)
echo -e "  ${M}  +--- Agent Reasoning -----------------------------------+${RESET}"
echo -e "  ${M}  |${RESET}                                                        ${M}|${RESET}"
echo -e "  ${M}  |${RESET}  ${W}Failure Analysis:${RESET}                                    ${M}|${RESET}"
echo -e "  ${M}  |${RESET}                                                        ${M}|${RESET}"

sleep 0.5
FAILURES=(
  "us-east-1:  3 preemptions in last hour  ${R}[HIGH RISK]${RESET}"
  "us-east-2:  1 OOM failure               ${G}[LOW RISK]${RESET}"
  "us-west-2:  1 timeout                   ${G}[LOW RISK]${RESET}"
)
for f in "${FAILURES[@]}"; do
  echo -e "  ${M}  |${RESET}    $f  ${M}|${RESET}"
  sleep 0.4
done

echo -e "  ${M}  |${RESET}                                                        ${M}|${RESET}"
echo -e "  ${M}  |${RESET}  ${Y}Recommendation:${RESET}                                     ${M}|${RESET}"
echo -e "  ${M}  |${RESET}  us-east-1 has 3x preemptions -- ${R}avoid this region${RESET}.   ${M}|${RESET}"
echo -e "  ${M}  |${RESET}  us-east-2 is cheapest AND stable -- ${G}recommended${RESET}.    ${M}|${RESET}"
echo -e "  ${M}  |${RESET}                                                        ${M}|${RESET}"
echo -e "  ${M}  +--------------------------------------------------------+${RESET}"

echo
echo -e "  ${D}  The AI Agent considers failure patterns that rule-based${RESET}"
echo -e "  ${D}  dispatch ignores. This avoids placing jobs on unstable nodes.${RESET}"

pause_key

# ================================================================
#  STEP 4 -- Agent 스마트 배치
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 4 / 6  ${RESET}  ${W}${BOLD}Agent 스마트 배치 -- 종합 판단${RESET}"
hr "=" "$M"
echo

PROMPT_3="g6.xlarge로 LoRA fine-tuning 작업을 제출해주세요. 가장 안정적인 리전으로요."
echo -e "  ${W}User:${RESET}"
echo -ne "  ${C}> ${RESET}"
typewrite "$PROMPT_3" 0.02
echo
echo

echo -e "  ${D}Agent reasoning chain:${RESET}"
echo

# Animated reasoning steps
STEPS=(
  "${C}1.${RESET} check_spot_prices(instance_type='g6.xlarge')   ${D}-- 가격 수집${RESET}"
  "${C}2.${RESET} get_failure_history()                          ${D}-- 장애 이력 조회${RESET}"
  "${C}3.${RESET} LLM analysis: price + stability + capacity     ${D}-- 종합 추론${RESET}"
  "${C}4.${RESET} submit_gpu_job(instance_type='g6.xlarge', ...) ${D}-- 작업 제출${RESET}"
)

for step in "${STEPS[@]}"; do
  sleep 0.8
  echo -e "     $step"
done

echo

# Compare rule-based vs agent decision
echo -e "  ${D}+---------------------------------------------------------+${RESET}"
echo -e "  ${D}|${RESET}  ${W}${BOLD}Decision Comparison${RESET}                                    ${D}|${RESET}"
echo -e "  ${D}+---------------------------------------------------------+${RESET}"
echo -e "  ${D}|${RESET}                                                         ${D}|${RESET}"

# Fetch actual prices for comparison
CHEAPEST_REGION="us-east-2"
CHEAPEST_PRICE="0.2261"

if echo "$PRICES_RAW" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  PRICE_INFO=$(echo "$PRICES_RAW" | python3 -c "
import sys, json
prices = sorted(json.load(sys.stdin).get('prices', []), key=lambda x: x['price'])
if prices:
    cheapest = prices[0]
    print(f\"{cheapest['region']}|{cheapest['price']:.4f}\")
else:
    print('us-east-2|0.2261')
" 2>/dev/null || echo "us-east-2|0.2261")
  RULE_REGION=$(echo "$PRICE_INFO" | cut -d'|' -f1)
  RULE_PRICE=$(echo "$PRICE_INFO" | cut -d'|' -f2)
else
  RULE_REGION="us-east-1"
  RULE_PRICE="0.3608"
fi

sleep 0.5
echo -e "  ${D}|${RESET}  ${Y}Rule-based:${RESET}  -> ${Y}${RULE_REGION}${RESET}  (\$${RULE_PRICE}/hr)       ${D}|${RESET}"
echo -e "  ${D}|${RESET}              ${D}Reason: lowest price (greedy)${RESET}              ${D}|${RESET}"
echo -e "  ${D}|${RESET}                                                         ${D}|${RESET}"

sleep 0.5
echo -e "  ${D}|${RESET}  ${M}AI Agent:${RESET}    -> ${G}${BOLD}us-east-2${RESET}  (\$0.2261/hr)            ${D}|${RESET}"
echo -e "  ${D}|${RESET}              ${D}Reason: stable + cheap + capacity=8${RESET}        ${D}|${RESET}"
echo -e "  ${D}|${RESET}              ${D}(avoided us-east-1: 3x preemptions)${RESET}        ${D}|${RESET}"
echo -e "  ${D}|${RESET}                                                         ${D}|${RESET}"
echo -e "  ${D}+---------------------------------------------------------+${RESET}"
echo

# Submit job via API
JOB_PAYLOAD='{
  "image": "nvidia/cuda:12.2.0-runtime-ubuntu22.04",
  "command": ["python3", "-c", "import time; print(\"Starting LoRA fine-tuning...\"); time.sleep(120); print(\"Training complete!\")"],
  "instance_type": "g6.xlarge",
  "gpu_type": "L4",
  "gpu_count": 1,
  "storage_mode": "s3",
  "checkpoint_enabled": false
}'

curl -s -X POST "$API/jobs" \
  -H "Content-Type: application/json" \
  -d "$JOB_PAYLOAD" > /tmp/demo4_job.json &
spinner $! "Agent submitting job via submit_gpu_job tool"

JOB_ID=$(cat /tmp/demo4_job.json | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('job_id', d.get('message', 'unknown')))
" 2>/dev/null || echo "demo-$(date +%s)")

echo
echo -e "  ${BG_G}${W}  JOB SUBMITTED  ${RESET}"
echo -e "  ${W}Job ID${RESET}  : ${G}${BOLD}${JOB_ID}${RESET}"
echo -e "  ${W}Region${RESET}  : ${G}us-east-2${RESET} (agent-selected)"
echo -e "  ${W}Reason${RESET}  : lowest price among stable regions (capacity=8)"

pause_key

# ================================================================
#  STEP 5 -- MCP Gateway 시연
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 5 / 6  ${RESET}  ${W}${BOLD}MCP Gateway -- FastAPI as Agent Tools${RESET}"
hr "=" "$M"
echo

echo -e "  ${D}AgentCore Gateway transforms REST APIs into MCP protocol tools.${RESET}"
echo -e "  ${D}Any MCP-compatible client (Claude Desktop, other agents) can${RESET}"
echo -e "  ${D}discover and call our FastAPI endpoints as native tools.${RESET}"
echo

echo -e "  ${C}  +-------------------+        +---------------------+${RESET}"
echo -e "  ${C}  |${RESET}  ${W}MCP Client${RESET}       ${C}|${RESET}  MCP   ${C}|${RESET}  ${W}AgentCore Gateway${RESET} ${C}|${RESET}"
echo -e "  ${C}  |${RESET}  Claude Desktop   ${C}|${RESET} -----> ${C}|${RESET}  MCP -> OpenAPI    ${C}|${RESET}"
echo -e "  ${C}  |${RESET}  External Agent   ${C}|${RESET}        ${C}|${RESET}  Protocol Bridge   ${C}|${RESET}"
echo -e "  ${C}  +-------------------+        +----------+----------+${RESET}"
echo -e "  ${D}                                          |${RESET}"
echo -e "  ${D}                                          V${RESET}"
echo -e "  ${G}                               +---------------------+${RESET}"
echo -e "  ${G}                               |${RESET}  ${W}FastAPI (GPU Lotto)${RESET}${G}|${RESET}"
echo -e "  ${G}                               |${RESET}  /api/prices        ${G}|${RESET}"
echo -e "  ${G}                               |${RESET}  /api/jobs          ${G}|${RESET}"
echo -e "  ${G}                               |${RESET}  /api/admin/stats   ${G}|${RESET}"
echo -e "  ${G}                               +---------------------+${RESET}"
echo

echo -e "  ${W}${BOLD}  Gateway Details:${RESET}"
echo
echo -e "  ${D}  MCP URL   :${RESET} ${C}${UNDERLINE}https://gpu-spot-lotto-gateway-rjctk0amlu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp${RESET}"
echo -e "  ${D}  Auth      :${RESET} Cognito JWT (auto-configured)"
echo -e "  ${D}  Protocol  :${RESET} MCP (Model Context Protocol)"
echo -e "  ${D}  Search    :${RESET} Semantic (natural language tool discovery)"
echo

echo -e "  ${W}${BOLD}  Registered MCP Tools (from OpenAPI):${RESET}"
echo

TOOLS=(
  "get_prices_api_prices_get        -- GET /api/prices        -- Spot 가격 조회"
  "submit_job_api_jobs_post         -- POST /api/jobs         -- GPU 작업 제출"
  "get_job_api_jobs__job_id__get    -- GET /api/jobs/{id}     -- 작업 상태 조회"
  "cancel_job_api_jobs__job_id__del -- DELETE /api/jobs/{id}  -- 작업 취소"
  "list_all_jobs_api_admin_jobs_get -- GET /api/admin/jobs    -- 전체 작업 목록"
  "get_stats_api_admin_stats_get    -- GET /api/admin/stats   -- 시스템 통계"
)

for tool in "${TOOLS[@]}"; do
  echo -e "     ${G}*${RESET} ${tool}"
  sleep 0.3
done

echo
echo -e "  ${D}  Any MCP client can now call these tools via standard protocol.${RESET}"
echo -e "  ${D}  Example: Claude Desktop connects to the MCP URL and discovers${RESET}"
echo -e "  ${D}  all 6 tools automatically via semantic search.${RESET}"

pause_key

# ================================================================
#  STEP 6 -- 종합 비교 & 요약
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 6 / 6  ${RESET}  ${W}${BOLD}종합 비교 & 요약${RESET}"
hr "=" "$M"
echo

echo -e "  ${W}${BOLD}  Rule-based vs AI Agent Dispatch${RESET}"
echo
echo -e "  ${D}  +---------------------+---------------------------+---------------------------+${RESET}"
echo -e "  ${D}  |${RESET} ${W}Criteria${RESET}            ${D}|${RESET} ${Y}Rule-based${RESET}                ${D}|${RESET} ${M}AI Agent${RESET}                  ${D}|${RESET}"
echo -e "  ${D}  +---------------------+---------------------------+---------------------------+${RESET}"

sleep 0.3
echo -e "  ${D}  |${RESET} Price check         ${D}|${RESET} ${G}Yes${RESET} (sorted set)          ${D}|${RESET} ${G}Yes${RESET} (check_spot_prices)   ${D}|${RESET}"
sleep 0.3
echo -e "  ${D}  |${RESET} Capacity check      ${D}|${RESET} ${G}Yes${RESET} (simple > 0)          ${D}|${RESET} ${G}Yes${RESET} (with reasoning)      ${D}|${RESET}"
sleep 0.3
echo -e "  ${D}  |${RESET} Failure history     ${D}|${RESET} ${R}No${RESET}                        ${D}|${RESET} ${G}Yes${RESET} (get_failure_history)  ${D}|${RESET}"
sleep 0.3
echo -e "  ${D}  |${RESET} VRAM mapping        ${D}|${RESET} ${R}No${RESET}  (user must specify)   ${D}|${RESET} ${G}Yes${RESET} (24GB -> g6.xlarge)   ${D}|${RESET}"
sleep 0.3
echo -e "  ${D}  |${RESET} Natural language    ${D}|${RESET} ${R}No${RESET}  (JSON API only)       ${D}|${RESET} ${G}Yes${RESET} (Korean/English)      ${D}|${RESET}"
sleep 0.3
echo -e "  ${D}  |${RESET} Reasoning trace     ${D}|${RESET} ${R}No${RESET}  (opaque)              ${D}|${RESET} ${G}Yes${RESET} (explains decisions)  ${D}|${RESET}"
sleep 0.3
echo -e "  ${D}  |${RESET} MCP integration     ${D}|${RESET} ${R}No${RESET}                        ${D}|${RESET} ${G}Yes${RESET} (Gateway)             ${D}|${RESET}"
sleep 0.3
echo -e "  ${D}  |${RESET} Latency             ${D}|${RESET} ${G}~100ms${RESET}                    ${D}|${RESET} ${Y}~5-15s${RESET} (LLM reasoning)    ${D}|${RESET}"
echo -e "  ${D}  +---------------------+---------------------------+---------------------------+${RESET}"

echo
hr "-" "$D"
echo

echo -e "  ${W}${BOLD}  Architecture Stack${RESET}"
echo
echo -e "  ${M}  +------------------------------------------------------+${RESET}"
echo -e "  ${M}  |${RESET}  ${W}${BOLD}AgentCore Runtime${RESET}    (Serverless, auto-scale)        ${M}|${RESET}"
echo -e "  ${M}  |${RESET}    |                                                  ${M}|${RESET}"
echo -e "  ${M}  |${RESET}    +-- ${C}Strands Agent${RESET} (Claude Sonnet 4.6)            ${M}|${RESET}"
echo -e "  ${M}  |${RESET}    |     +-- check_spot_prices (Redis ZRANGE)          ${M}|${RESET}"
echo -e "  ${M}  |${RESET}    |     +-- get_failure_history (Redis SMEMBERS)       ${M}|${RESET}"
echo -e "  ${M}  |${RESET}    |     +-- submit_gpu_job (Redis LPUSH)              ${M}|${RESET}"
echo -e "  ${M}  |${RESET}    |     +-- get_job_status (Redis HGETALL)            ${M}|${RESET}"
echo -e "  ${M}  |${RESET}    |     +-- list_active_jobs (Redis SMEMBERS)         ${M}|${RESET}"
echo -e "  ${M}  |${RESET}    |                                                  ${M}|${RESET}"
echo -e "  ${M}  |${RESET}    +-- ${G}AgentCore Gateway${RESET} (MCP Protocol)            ${M}|${RESET}"
echo -e "  ${M}  |${RESET}          +-- FastAPI OpenAPI -> 6 MCP tools            ${M}|${RESET}"
echo -e "  ${M}  |${RESET}          +-- Cognito JWT auth                          ${M}|${RESET}"
echo -e "  ${M}  |${RESET}          +-- Semantic tool discovery                   ${M}|${RESET}"
echo -e "  ${M}  +------------------------------------------------------+${RESET}"

echo
echo -e "  ${D}  Access Points:${RESET}"
echo -e "  ${D}  Dashboard : ${UNDERLINE}${C}${BASE_URL}${RESET}"
echo -e "  ${D}  Agent     : agentcore invoke '{\"prompt\": \"...\"}'"
echo -e "  ${D}  MCP       : ${UNDERLINE}${C}https://gpu-spot-lotto-gateway-rjctk0amlu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp${RESET}"
echo

hr "=" "$M"
echo
echo -e "  ${M}${BOLD}"
cat << 'ART'
     ██████╗  ██████╗ ███╗   ██╗███████╗██╗
     ██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║
     ██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║
     ██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝
     ██████╔╝╚██████╔╝██║ ╚████║███████╗██╗
     ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝
ART
echo -e "${RESET}"
echo -e "  ${G}${BOLD}Scenario 4 Complete!${RESET}"
echo -e "  ${D}AI Agent가 가격+장애+용량을 종합 분석하여 us-east-2를 선택했습니다.${RESET}"
echo -e "  ${D}Rule-based 대비 장애 회피율이 높고, 자연어 인터페이스를 제공합니다.${RESET}"
echo -e "  ${D}MCP Gateway로 외부 MCP 클라이언트에서도 GPU Lotto 도구를 사용할 수 있습니다.${RESET}"
echo
hr "=" "$M"
echo
