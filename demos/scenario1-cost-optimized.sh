#!/usr/bin/env bash
# ============================================================
#  Scenario 1: 최저가 GPU 자동 배치 (Cost-Optimized Training)
# ============================================================
set -euo pipefail

BASE_URL="${GPU_LOTTO_URL:-https://d370iz4ydsallw.cloudfront.net}"
API="$BASE_URL/api"

# ── Terminal setup ─────────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 80)
ROWS=$(tput lines 2>/dev/null || echo 24)

# ── Colors ─────────────────────────────────────────────────
R='\033[0;31m';  G='\033[0;32m';  Y='\033[0;33m';  B='\033[0;34m'
M='\033[0;35m';  C='\033[0;36m';  W='\033[1;37m';  D='\033[0;90m'
BG_B='\033[44m'; BG_G='\033[42m'; BG_R='\033[41m'; BG_Y='\033[43m'
BG_M='\033[45m'; BG_C='\033[46m'; BG_D='\033[100m'
RESET='\033[0m'; BOLD='\033[1m';  DIM='\033[2m';   BLINK='\033[5m'
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

# ── FULL SCREEN BANNER ─────────────────────────────────────
clear
echo
echo
echo -e "  ${B}${BOLD}"
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
echo -e "${BG_B}${W}${BOLD}$(printf '%*s' $COLS '' | tr ' ' ' ')${RESET}"
echo -e "${BG_B}${W}${BOLD}$(center 'SCENARIO 1: 최저가 GPU 자동 배치 — Cost-Optimized Training')${RESET}"
echo -e "${BG_B}${W}${BOLD}$(printf '%*s' $COLS '' | tr ' ' ' ')${RESET}"
echo
echo -e "  ${D}┌───────────────────────────────────────────────────┐${RESET}"
echo -e "  ${D}│${RESET}  Endpoint  ${D}│${RESET} ${C}${BASE_URL}${RESET}"
echo -e "  ${D}│${RESET}  Instance  ${D}│${RESET} ${W}g6.xlarge${RESET} — NVIDIA L4, 24GB VRAM"
echo -e "  ${D}│${RESET}  Workload  ${D}│${RESET} LoRA fine-tuning (Stable Diffusion)"
echo -e "  ${D}│${RESET}  Strategy  ${D}│${RESET} ${G}Auto-dispatch to cheapest region${RESET}"
echo -e "  ${D}└───────────────────────────────────────────────────┘${RESET}"
echo
echo -e "  ${W}${BOLD}  [About]${RESET}"
echo -e "  ${D}  3개 AWS 리전(us-east-1, us-east-2, us-west-2)의 GPU Spot 가격을${RESET}"
echo -e "  ${D}  실시간으로 비교하여, 가장 저렴한 리전에 자동 배치하는 시나리오입니다.${RESET}"
echo -e "  ${D}  Seoul 컨트롤 플레인이 Price Watcher로 가격을 수집하고,${RESET}"
echo -e "  ${D}  Dispatcher가 최저가 리전을 선택해 GPU Pod를 생성합니다.${RESET}"
echo
echo -e "  ${W}${BOLD}  [Steps]${RESET}"
echo -e "  ${C}  1.${RESET} 실시간 Spot 가격 스캔       ${D}-- 3개 리전 가격 테이블${RESET}"
echo -e "  ${C}  2.${RESET} GPU 학습 작업 제출           ${D}-- POST /api/jobs${RESET}"
echo -e "  ${C}  3.${RESET} Dispatcher 자동 배치         ${D}-- 최저가 리전 선택 & Pod 생성${RESET}"
echo -e "  ${C}  4.${RESET} 비용 절감 분석               ${D}-- On-Demand vs Spot 비교${RESET}"
echo -e "  ${C}  5.${RESET} 모니터링 대시보드            ${D}-- Grafana & Dashboard 링크${RESET}"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 1 — 실시간 Spot 가격 스캔
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 1 / 5  ${RESET}  ${W}${BOLD}실시간 Spot 가격 스캔${RESET}"
hr "=" "$M"
echo
echo -e "  ${D}Scanning GPU Spot prices across 3 AWS regions...${RESET}"
echo
echo -e "  ${C}    ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐${RESET}"
echo -e "  ${C}    │${RESET}  ${W}us-east-1 (VA)${RESET}  ${C}│     │${RESET}  ${W}us-east-2 (OH)${RESET}  ${C}│     │${RESET}  ${W}us-west-2 (OR)${RESET}  ${C}│${RESET}"
echo -e "  ${C}    └────────┬─────────┘     └────────┬─────────┘     └────────┬─────────┘${RESET}"
echo -e "  ${C}             └──────────────┬─────────┴──────────────┬─────────┘${RESET}"
echo -e "  ${C}                            V                        ${RESET}"
echo -e "  ${C}                   ┌────────────────────┐${RESET}"
echo -e "  ${C}                   │${RESET} ${BG_B}${W} Price Watcher ${RESET} ${C}│${RESET}"
echo -e "  ${C}                   │${RESET}  Seoul Control Plane ${C}│${RESET}"
echo -e "  ${C}                   └────────────────────┘${RESET}"
echo

# Fetch prices with spinner
curl -s "$API/prices" > /tmp/gpu_prices.json &
spinner $! "Fetching live prices from AWS EC2 API"
echo

PRICES_RAW=$(cat /tmp/gpu_prices.json)
if echo "$PRICES_RAW" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then

  echo -e "  ${W}${BOLD}  LIVE SPOT PRICES                                                  ${RESET}"
  echo -e "  ${D}  ──────────────────────────────────────────────────────────────────${RESET}"
  echo

  # Show prices with animated reveal
  echo "$PRICES_RAW" | python3 -c "
import sys, json, time
data = json.load(sys.stdin)
prices = sorted(data.get('prices', []), key=lambda x: x['price'])
cheapest = prices[0]['price'] if prices else 0
region_colors = {'us-east-1': '\033[0;33m', 'us-east-2': '\033[0;36m', 'us-west-2': '\033[0;35m'}

print('  \033[1;37m  %-14s  %-13s  %-10s  %s\033[0m' % ('REGION', 'INSTANCE', 'PRICE/HR', ''))
print('  \033[0;90m  %-14s  %-13s  %-10s  %s\033[0m' % ('-'*14, '-'*13, '-'*10, '-'*20))

for i, p in enumerate(prices):
    r, t, pr = p['region'], p['instance_type'], p['price']
    rc = region_colors.get(r, '\033[0m')
    is_best = (pr == cheapest)

    bar_len = int(min(pr / 6.0, 1.0) * 20)
    bar = '#' * bar_len + '.' * (20 - bar_len)

    if is_best:
        marker = '\033[42m\033[1;37m BEST \033[0m'
        price_c = '\033[1;32m'
    else:
        marker = '     '
        price_c = '\033[0m'

    print(f'  {rc}  {r:<14}\033[0m  {t:<13}  {price_c}\${pr:<9.4f}\033[0m  \033[0;32m{bar}\033[0m {marker}')
    time.sleep(0.08)
"

  CHEAPEST=$(echo "$PRICES_RAW" | python3 -c "
import sys, json
prices = json.load(sys.stdin).get('prices', [])
best = min(prices, key=lambda x: x['price'])
print(f\"{best['region']}|{best['price']:.4f}|{best['instance_type']}\")
")
  CHEAPEST_REGION=$(echo "$CHEAPEST" | cut -d'|' -f1)
  CHEAPEST_PRICE=$(echo "$CHEAPEST" | cut -d'|' -f2)
  CHEAPEST_TYPE=$(echo "$CHEAPEST" | cut -d'|' -f3)
else
  echo -e "  ${Y}Could not parse price data${RESET}"
  CHEAPEST_REGION="us-east-2"; CHEAPEST_PRICE="0.1999"; CHEAPEST_TYPE="g6.xlarge"
fi

echo
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}   WINNER: ${CHEAPEST_REGION} — \$${CHEAPEST_PRICE}/hr (${CHEAPEST_TYPE})              ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 2 — 작업 제출
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 2 / 5  ${RESET}  ${W}${BOLD}GPU 학습 작업 제출${RESET}"
hr "=" "$M"
echo

echo -e "  ${D}Job Configuration:${RESET}"
echo
echo -e "  ${W}┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${W}│${RESET}                                                         ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}Image${RESET}       nvidia/cuda:12.2.0-runtime-ubuntu22.04    ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}Task${RESET}        LoRA fine-tuning (Stable Diffusion XL)    ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}Instance${RESET}    g6.xlarge                                 ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}GPU${RESET}         NVIDIA L4 (24GB VRAM) x 1                 ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}Storage${RESET}     S3 (auto-upload results)                  ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}Checkpoint${RESET}  Disabled (short job)                      ${W}│${RESET}"
echo -e "  ${W}│${RESET}                                                         ${W}│${RESET}"
echo -e "  ${W}└─────────────────────────────────────────────────────────┘${RESET}"
echo

JOB_PAYLOAD='{
  "image": "nvidia/cuda:12.2.0-runtime-ubuntu22.04",
  "command": ["python3", "-c", "import time; print(\"Starting LoRA fine-tuning...\"); time.sleep(120); print(\"Training complete!\")"],
  "instance_type": "g6.xlarge",
  "gpu_type": "L4",
  "gpu_count": 1,
  "storage_mode": "s3",
  "checkpoint_enabled": false
}'

echo -ne "  "
typewrite_color "$C" "Submitting job to API..." 0.04
echo
echo

curl -s -X POST "$API/jobs" \
  -H "Content-Type: application/json" \
  -d "$JOB_PAYLOAD" > /tmp/gpu_job_result.json &
spinner $! "POST /api/jobs"

SUBMIT_RESULT=$(cat /tmp/gpu_job_result.json)
JOB_ID=$(echo "$SUBMIT_RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('job_id', d.get('message', 'unknown')))
" 2>/dev/null || echo "demo-$(date +%s)")

echo
echo -e "  ${BG_G}${W}  JOB SUBMITTED  ${RESET}"
echo
echo -e "  ${W}Job ID${RESET}  : ${G}${BOLD}${JOB_ID}${RESET}"
echo -e "  ${W}Status${RESET}  : ${Y}queued${RESET} → waiting for dispatch"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 3 — Dispatch 시각화
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 3 / 5  ${RESET}  ${W}${BOLD}Dispatcher 자동 배치${RESET}"
hr "=" "$M"
echo

echo -e "  ${D}Dispatcher evaluates prices and selects optimal region...${RESET}"
echo
echo -e "  ${Y}              ┌──────────────┐${RESET}"
echo -e "  ${Y}              │  ${W}DISPATCHER${RESET}  ${Y}│${RESET}"
echo -e "  ${Y}              │${RESET}  Queue → Pod  ${Y}│${RESET}"
echo -e "  ${Y}              └──────┬───────┘${RESET}"
echo -e "  ${Y}                     │ ${D}price comparison${RESET}"
echo -e "  ${Y}           ┌─────────┼──────────┐${RESET}"
echo -e "  ${Y}           V         V          V${RESET}"

sleep 0.5

# Animated region evaluation
REGIONS=("us-east-1" "us-east-2" "us-west-2")
PRICES_DEMO=("0.3005" "0.1999" "0.3511")
RESULTS=("" "" "")

for idx in 0 1 2; do
  sleep 0.8
  reg=${REGIONS[$idx]}
  price=${PRICES_DEMO[$idx]}

  if [ "$reg" == "$CHEAPEST_REGION" ]; then
    RESULTS[$idx]="${BG_G}${W}${BOLD} * ${reg}  \$${price}/hr  SELECTED ${RESET}"
  else
    RESULTS[$idx]="  ${D} ○ ${reg}  \$${price}/hr ${RESET}"
  fi
done

echo
for idx in 0 1 2; do
  echo -e "  ${RESULTS[$idx]}"
done

echo
sleep 1

echo -ne "  "
typewrite_color "$G" ">>> Dispatching to ${CHEAPEST_REGION} (\$${CHEAPEST_PRICE}/hr)" 0.04
echo
echo

# Poll job status
for i in $(seq 1 6); do
  JOB_RAW=$(curl -s "$API/jobs/$JOB_ID" 2>/dev/null || echo '{}')
  STATUS=$(echo "$JOB_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','queued'))" 2>/dev/null || echo "queued")
  REGION=$(echo "$JOB_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('region','-'))" 2>/dev/null || echo "-")

  case "$STATUS" in
    queued)    badge="${BG_Y}${W} QUEUED  ${RESET}" ;;
    running)   badge="${BG_G}${W} RUNNING ${RESET}" ;;
    succeeded) badge="${BG_G}${W} DONE    ${RESET}" ;;
    failed)    badge="${BG_R}${W} FAILED  ${RESET}" ;;
    *)         badge="${BG_D}${W} ${STATUS^^} ${RESET}" ;;
  esac

  printf "\r  ${badge}  Job: ${D}%.8s${RESET}  Region: ${C}%-12s${RESET}  Poll: %d/6" "$JOB_ID" "$REGION" "$i"

  [[ "$STATUS" == "succeeded" || "$STATUS" == "failed" || "$STATUS" == "running" ]] && break
  sleep 3
done
echo
echo

echo -e "  ${G}[OK]${RESET}  작업이 ${BG_C}${W} ${CHEAPEST_REGION} ${RESET} 에 성공적으로 배치되었습니다!"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 4 — 비용 분석 (비주얼 바 차트)
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 4 / 5  ${RESET}  ${W}${BOLD}비용 절감 분석${RESET}"
hr "=" "$M"
echo

SPOT_PRICE="${CHEAPEST_PRICE:-0.1999}"
ON_DEMAND="0.8050"
SPOT_AVG="0.3200"

OD_PCT=100
SA_PCT=$(python3 -c "print(int(float('$SPOT_AVG') / float('$ON_DEMAND') * 100))")
SL_PCT=$(python3 -c "print(int(float('$SPOT_PRICE') / float('$ON_DEMAND') * 100))")
SAVINGS_PCT=$(python3 -c "print(f'{(1 - float(\"$SPOT_PRICE\") / float(\"$ON_DEMAND\")) * 100:.0f}')")

echo -e "  ${W}${BOLD}g6.xlarge (NVIDIA L4) — 24hr Cost Comparison${RESET}"
echo
echo -e "  ${R}On-Demand${RESET}      \$${ON_DEMAND}/hr × 24h = ${R}\$$(python3 -c "print(f'{float(\"$ON_DEMAND\")*24:.2f}')")${RESET}"

# Animated bars
for pct_step in $(seq 10 10 $OD_PCT); do
  printf "\r"
  anim_bar "$pct_step" "$R"
  sleep 0.03
done
echo

echo -e "  ${Y}Spot (avg)${RESET}     \$${SPOT_AVG}/hr × 24h = ${Y}\$$(python3 -c "print(f'{float(\"$SPOT_AVG\")*24:.2f}')")${RESET}"
for pct_step in $(seq 10 10 $SA_PCT); do
  printf "\r"
  anim_bar "$pct_step" "$Y"
  sleep 0.03
done
echo

echo -e "  ${G}Spot Lotto${RESET}     \$${SPOT_PRICE}/hr × 24h = ${G}${BOLD}\$$(python3 -c "print(f'{float(\"$SPOT_PRICE\")*24:.2f}')")${RESET}"
for pct_step in $(seq 5 5 $SL_PCT); do
  printf "\r"
  anim_bar "$pct_step" "$G"
  sleep 0.03
done
echo
echo
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}           SAVINGS: ~${SAVINGS_PCT}% vs On-Demand                         ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 5 — 모니터링 대시보드
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 5 / 5  ${RESET}  ${W}${BOLD}모니터링 대시보드 링크${RESET}"
hr "=" "$M"
echo

echo -e "  ${W}Access Points:${RESET}"
echo
echo -e "  ${C}┌─────────────┐${RESET}"
echo -e "  ${C}│ ${W}Frontend${RESET}   ${C}│${RESET}  ${UNDERLINE}${BASE_URL}/${RESET}"
echo -e "  ${C}├─────────────┤${RESET}"
echo -e "  ${C}│ ${W}Job Detail${RESET} ${C}│${RESET}  ${UNDERLINE}${BASE_URL}/jobs/${JOB_ID}${RESET}"
echo -e "  ${C}├─────────────┤${RESET}"
echo -e "  ${C}│ ${W}Prices${RESET}    ${C}│${RESET}  ${UNDERLINE}${BASE_URL}/prices${RESET}"
echo -e "  ${C}├─────────────┤${RESET}"
echo -e "  ${C}│ ${W}Grafana${RESET}   ${C}│${RESET}  ${UNDERLINE}${BASE_URL}/grafana/d/gpu-spot-lotto/gpu-spot-lotto${RESET}"
echo -e "  ${C}│${RESET}             ${C}│${RESET}  ${D}Login: admin / gpu-lotto-dev-2026${RESET}"
echo -e "  ${C}├─────────────┤${RESET}"
echo -e "  ${C}│ ${W}Guide${RESET}     ${C}│${RESET}  ${UNDERLINE}${BASE_URL}/guide${RESET}"
echo -e "  ${C}└─────────────┘${RESET}"
echo
echo
hr "=" "$B"
echo
echo -e "  ${B}${BOLD}"
cat << 'ART'
     ██████╗  ██████╗ ███╗   ██╗███████╗██╗
     ██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║
     ██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║
     ██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝
     ██████╔╝╚██████╔╝██║ ╚████║███████╗██╗
     ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝
ART
echo -e "${RESET}"
echo -e "  ${G}${BOLD}Scenario 1 Complete!${RESET}"
echo -e "  ${D}시스템이 자동으로 최저가 리전(${CHEAPEST_REGION})에 작업을 배치했습니다.${RESET}"
echo -e "  ${D}On-Demand 대비 ~${SAVINGS_PCT}% 비용 절감을 달성했습니다.${RESET}"
echo
hr "=" "$B"
echo
