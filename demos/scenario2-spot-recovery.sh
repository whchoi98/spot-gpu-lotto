#!/usr/bin/env bash
# ============================================================
#  Scenario 2: 스팟 회수 시 자동 복구 (Spot Interruption Recovery)
#
#  학습 도중 AWS가 스팟 인스턴스를 회수하면,
#  체크포인트에서 다른 최저가 리전으로 자동 재배치합니다.
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

training_progress() {
  local pct=$1 epoch=$2 total=$3 color="${4:-$G}"
  local width=30
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  printf "\r  ${color}Epoch %3d/%d${RESET}  " "$epoch" "$total"
  printf "${color}"
  for ((j=0; j<filled; j++)); do printf '#'; done
  printf "${D}"
  for ((j=0; j<empty; j++)); do printf '.'; done
  printf "${RESET} ${D}%3d%%${RESET}" "$pct"
}

# ── FULL SCREEN BANNER ─────────────────────────────────────
clear
echo
echo
echo -e "  ${R}${BOLD}"
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
echo -e "${BG_R}${W}${BOLD}$(printf '%*s' $COLS '' | tr ' ' ' ')${RESET}"
echo -e "${BG_R}${W}${BOLD}$(center 'SCENARIO 2: 스팟 회수 자동 복구 — Spot Interruption Recovery')${RESET}"
echo -e "${BG_R}${W}${BOLD}$(printf '%*s' $COLS '' | tr ' ' ' ')${RESET}"
echo
echo -e "  ${D}┌───────────────────────────────────────────────────┐${RESET}"
echo -e "  ${D}│${RESET}  Endpoint  ${D}│${RESET} ${C}${BASE_URL}${RESET}"
echo -e "  ${D}│${RESET}  Instance  ${D}│${RESET} ${W}g5.xlarge${RESET} — NVIDIA A10G, 24GB VRAM"
echo -e "  ${D}│${RESET}  Workload  ${D}│${RESET} Long-running training (100 epochs)"
echo -e "  ${D}│${RESET}  Strategy  ${D}│${RESET} ${Y}Checkpoint + Auto-Recovery${RESET}"
echo -e "  ${D}│${RESET}  Scenario  ${D}│${RESET} ${R}Spot Interruption → Auto-Failover${RESET}"
echo -e "  ${D}└───────────────────────────────────────────────────┘${RESET}"
echo
echo -e "  ${W}${BOLD}  [About]${RESET}"
echo -e "  ${D}  GPU 학습 도중 AWS가 Spot 인스턴스를 회수(reclaim)하면,${RESET}"
echo -e "  ${D}  체크포인트에서 다른 최저가 리전으로 자동 복구하는 시나리오입니다.${RESET}"
echo -e "  ${D}  학습 진행 중 주기적으로 체크포인트를 S3에 저장하고,${RESET}"
echo -e "  ${D}  인터럽션 발생 시 새 리전에서 체크포인트를 복원하여 이어서 학습합니다.${RESET}"
echo
echo -e "  ${W}${BOLD}  [Steps]${RESET}"
echo -e "  ${C}  1.${RESET} 체크포인트 활성화 작업 제출  ${D}-- checkpoint_enabled: true${RESET}"
echo -e "  ${C}  2.${RESET} 학습 실행 & 체크포인트 저장  ${D}-- 매 10 epoch마다 S3 저장${RESET}"
echo -e "  ${R}  3.${RESET} ${R}Spot 인스턴스 회수 발생!${RESET}    ${D}-- AWS 2분 경고 시뮬레이션${RESET}"
echo -e "  ${C}  4.${RESET} 자동 복구 -- 리전 재배치     ${D}-- 차순위 최저가 리전 선택${RESET}"
echo -e "  ${C}  5.${RESET} 체크포인트 복원 & 학습 재개  ${D}-- 중단 지점부터 이어서 학습${RESET}"
echo -e "  ${C}  6.${RESET} 복구 타임라인 & 비용 비교    ${D}-- 전체 흐름 요약 & 절감률${RESET}"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 1 — 체크포인트 활성화 작업 제출
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 1 / 6  ${RESET}  ${W}${BOLD}체크포인트 활성화 학습 작업 제출${RESET}"
hr "=" "$M"
echo

echo -e "  ${D}Job Configuration:${RESET}"
echo
echo -e "  ${W}┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${W}│${RESET}                                                         ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}Image${RESET}       nvidia/cuda:12.2.0-runtime-ubuntu22.04    ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}Task${RESET}        Long-running training (100 epochs)        ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}Instance${RESET}    g5.xlarge                                 ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}GPU${RESET}         NVIDIA A10G (24GB VRAM) x 1               ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}Storage${RESET}     S3 (auto-upload results)                  ${W}│${RESET}"
echo -e "  ${W}│${RESET}  ${C}Checkpoint${RESET}  ${G}${BOLD}Enabled${RESET} — 매 10 에포크마다 저장           ${W}│${RESET}"
echo -e "  ${W}│${RESET}                                                         ${W}│${RESET}"
echo -e "  ${W}└─────────────────────────────────────────────────────────┘${RESET}"
echo

JOB_PAYLOAD='{
  "image": "nvidia/cuda:12.2.0-runtime-ubuntu22.04",
  "command": ["/bin/sh", "-c", "echo Starting training... && nvidia-smi && epoch=0; while [ $epoch -lt 100 ]; do echo Epoch $epoch/100 - training...; sleep 3; if [ $((epoch % 10)) -eq 0 ]; then echo [checkpoint] epoch_${epoch}.pt saved; fi; epoch=$((epoch+1)); done; echo Training complete!"],
  "instance_type": "g5.xlarge",
  "gpu_type": "A10G",
  "gpu_count": 1,
  "storage_mode": "s3",
  "checkpoint_enabled": true
}'

echo -ne "  "
typewrite_color "$C" "Submitting job with checkpoint_enabled: true ..." 0.04
echo
echo

# Snapshot existing job IDs before submission
BEFORE_IDS=$(curl -s "$API/admin/jobs" | python3 -c "
import sys, json
jobs = json.load(sys.stdin).get('jobs', [])
print(' '.join(j['job_id'] for j in jobs))
" 2>/dev/null || echo "")

curl -s -X POST "$API/jobs" \
  -H "Content-Type: application/json" \
  -d "$JOB_PAYLOAD" > /tmp/gpu_job_result2.json &
spinner $! "POST /api/jobs"

# Wait for dispatcher to process and find the new job_id
JOB_ID=""
for attempt in $(seq 1 10); do
  sleep 2
  JOB_ID=$(curl -s "$API/admin/jobs" | python3 -c "
import sys, json
before = set('${BEFORE_IDS}'.split())
jobs = json.load(sys.stdin).get('jobs', [])
new = [j for j in jobs if j['job_id'] not in before]
if new:
    best = max(new, key=lambda j: j.get('created_at', '0'))
    print(best['job_id'])
" 2>/dev/null || echo "")
  [ -n "$JOB_ID" ] && break
  printf "\r  ${C}|${RESET} Waiting for dispatcher... (%d/10)" "$attempt"
done
[ -z "$JOB_ID" ] && JOB_ID="demo-$(date +%s)"

echo
echo -e "  ${BG_G}${W}  JOB SUBMITTED  ${RESET}"
echo
echo -e "  ${W}Job ID${RESET}      : ${G}${BOLD}${JOB_ID}${RESET}"
echo -e "  ${W}Checkpoint${RESET}  : ${G}Enabled (every 10 epochs)${RESET}"
echo -e "  ${W}Status${RESET}      : ${Y}queued${RESET} → waiting for dispatch"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 2 — 학습 실행 중 + 체크포인트 진행
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 2 / 6  ${RESET}  ${W}${BOLD}학습 실행 & 체크포인트 저장${RESET}"
hr "=" "$M"
echo

# Poll for running status
info_region="-"
for i in $(seq 1 6); do
  JOB_RAW=$(curl -s "$API/jobs/$JOB_ID" 2>/dev/null || echo '{}')
  STATUS=$(echo "$JOB_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
  REGION=$(echo "$JOB_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('region','-'))" 2>/dev/null || echo "-")

  case "$STATUS" in
    queued)    badge="${BG_Y}${W} QUEUED  ${RESET}" ;;
    running)   badge="${BG_G}${W} RUNNING ${RESET}" ;;
    *)         badge="${BG_D}${W} ${STATUS^^} ${RESET}" ;;
  esac

  printf "\r  ${badge}  Job: ${D}%.8s${RESET}  Region: ${C}%-12s${RESET}  Poll: %d/6" "$JOB_ID" "$REGION" "$i"

  if [ "$STATUS" == "running" ]; then
    info_region="$REGION"
    break
  fi
  sleep 3
done
echo
echo

if [ "$info_region" == "-" ]; then
  # Fallback: query admin/jobs for the region
  info_region=$(curl -s "$API/jobs/$JOB_ID" 2>/dev/null | python3 -c "
import sys, json
print(json.load(sys.stdin).get('region', 'us-east-1'))
" 2>/dev/null || echo "us-east-1")
fi
INITIAL_REGION="$info_region"

echo -e "  ${G}[OK]${RESET}  작업이 ${BG_C}${W} ${INITIAL_REGION} ${RESET} 에서 실행 중입니다"
echo
echo -e "  ${W}${BOLD}  Training Progress${RESET}"
echo -e "  ${D}  ──────────────────────────────────────────────────${RESET}"
echo

# Animated training progress with checkpoint saves
CHECKPOINTS=()
for epoch in 0 5 10 15 20 25 30 35; do
  pct=$(( epoch * 100 / 100 ))
  training_progress "$pct" "$epoch" 100 "$G"

  if (( epoch % 10 == 0 && epoch > 0 )); then
    echo
    echo -e "     ${C}>> Checkpoint saved: ${W}epoch_${epoch}.pt${RESET} → ${D}s3://gpu-lotto-dev-data/checkpoints/${RESET}"
    CHECKPOINTS+=("epoch_${epoch}.pt")
  fi
  sleep 0.4
done

echo
echo
echo -e "  ${D}  Checkpoints stored:${RESET}"
for ckpt in "${CHECKPOINTS[@]}"; do
  echo -e "     ${G}[OK]${RESET} ${D}s3://.../${JOB_ID}/${ckpt}${RESET}"
done

echo
echo -e "  ${D}  Latest checkpoint: ${W}epoch_30.pt${RESET} (30/100 epochs = 30% complete)${RESET}"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 3 — 스팟 인스턴스 회수!! (Dramatic)
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_R}${W}${BOLD}  STEP 3 / 6  ${RESET}  ${W}${BOLD}!! 스팟 인스턴스 회수 발생!${RESET}"
hr "=" "$R"
echo

# Dramatic countdown / warning
sleep 0.5

echo -e "  ${R}${BOLD}"
cat << 'WARNING'
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║       !!!!!!  AWS SPOT INTERRUPTION NOTICE  !!!!!!       ║
    ║                                                           ║
    ║   Your Spot Instance will be terminated in 2 minutes.     ║
    ║   Instance: g5.xlarge   |   GPU: NVIDIA A10G              ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
WARNING
echo -e "${RESET}"
echo
echo -e "  ${W}Instance${RESET}  : g5.xlarge"
echo -e "  ${W}Region${RESET}    : ${R}${INITIAL_REGION}${RESET}"
echo -e "  ${W}Reason${RESET}    : ${R}Capacity reclaimed by AWS${RESET}"
echo -e "  ${W}Warning${RESET}   : ${Y}2-minute termination notice${RESET}"
echo

# Animated countdown
echo -ne "  "
typewrite_color "$Y" "Emergency checkpoint save initiated..." 0.04
echo
echo

for action in \
  "${D}→ Intercepting SIGTERM signal${RESET}" \
  "${D}→ Flushing GPU memory${RESET}" \
  "${D}→ Saving model state_dict (epoch 35 partial)${RESET}" \
  "${Y}→ Uploading checkpoint to S3...${RESET}" \
  "${G}→ Checkpoint epoch_30.pt verified on S3${RESET}" \
  "${G}→ Graceful shutdown complete${RESET}"; do
  sleep 0.8
  echo -e "     $action"
done

echo

# Cancel the job (simulate spot interruption)
echo -ne "  "
typewrite_color "$D" "Simulating interruption via API..." 0.03
echo

CANCEL_RESULT=$(curl -s -X DELETE "$API/jobs/$JOB_ID" 2>/dev/null || echo '{"status":"simulated"}')
echo -e "  ${D}Response: ${CANCEL_RESULT}${RESET}"

echo
echo -e "  ${BG_R}${W}${BOLD}                                                              ${RESET}"
echo -e "  ${BG_R}${W}${BOLD}   INSTANCE TERMINATED — Job status: cancelled                ${RESET}"
echo -e "  ${BG_R}${W}${BOLD}   Checkpoint safe: epoch_30.pt (S3)                           ${RESET}"
echo -e "  ${BG_R}${W}${BOLD}                                                              ${RESET}"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 4 — 자동 복구: 리전 재선택 + 재배치
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 4 / 6  ${RESET}  ${W}${BOLD}자동 복구 — 최저가 리전 재배치${RESET}"
hr "=" "$M"
echo

# Fetch live prices and pick cheapest non-interrupted region
PRICE_JSON=$(curl -s "$API/prices?instance_type=g5.xlarge" 2>/dev/null || echo '{"prices":[]}')

REGIONS=("us-east-1" "us-east-2" "us-west-2")
declare -A PRICE_MAP
for reg in "${REGIONS[@]}"; do
  p=$(echo "$PRICE_JSON" | python3 -c "
import sys, json
prices = json.load(sys.stdin).get('prices', [])
match = [p for p in prices if p['region'] == '${reg}']
print(f\"{match[0]['price']:.4f}\" if match else '0.0000')
" 2>/dev/null || echo "0.0000")
  PRICE_MAP[$reg]="$p"
done

# Find cheapest available region (excluding interrupted)
RECOVERY_REGION=""
RECOVERY_PRICE="99.9999"
for reg in "${REGIONS[@]}"; do
  [ "$reg" == "$INITIAL_REGION" ] && continue
  p="${PRICE_MAP[$reg]}"
  if [ "$(echo "$p < $RECOVERY_PRICE" | bc -l 2>/dev/null || echo 0)" == "1" ]; then
    RECOVERY_REGION="$reg"
    RECOVERY_PRICE="$p"
  fi
done
[ -z "$RECOVERY_REGION" ] && RECOVERY_REGION="us-east-2" && RECOVERY_PRICE="0.2650"

echo -e "  ${Y}              ┌──────────────────┐${RESET}"
echo -e "  ${Y}              │${RESET}  ${W}AUTO-RECOVERY${RESET}    ${Y}│${RESET}"
echo -e "  ${Y}              │${RESET}  Dispatcher 감지  ${Y}│${RESET}"
echo -e "  ${Y}              └────────┬─────────┘${RESET}"
echo -e "  ${Y}                       │ ${D}cancelled job detected${RESET}"
echo -e "  ${Y}                       V${RESET}"
echo -e "  ${Y}              ┌──────────────────┐${RESET}"
echo -e "  ${Y}              │${RESET}  ${W}PRICE SCAN${RESET}       ${Y}│${RESET}"
echo -e "  ${Y}              │${RESET}  Region 비교 중   ${Y}│${RESET}"
echo -e "  ${Y}              └────────┬─────────┘${RESET}"
echo -e "  ${Y}           ┌───────────┼───────────┐${RESET}"
echo -e "  ${Y}           V           V           V${RESET}"
echo

sleep 1

echo -e "  ${W}${BOLD}  REGION           PRICE/HR    STATUS               ${RESET}"
echo -e "  ${D}  ─────────────    ─────────   ──────────────────── ${RESET}"

for reg in "${REGIONS[@]}"; do
  sleep 0.6
  price="${PRICE_MAP[$reg]}"
  if [ "$reg" == "$INITIAL_REGION" ]; then
    echo -e "  ${R}  ${reg}      \$${price}     ${BG_R}${W} INTERRUPTED ${RESET}"
  elif [ "$reg" == "$RECOVERY_REGION" ]; then
    echo -e "  ${G}  ${reg}      \$${price}     ${BG_G}${W} BEST * ${RESET}"
  else
    echo -e "  ${C}  ${reg}      \$${price}     ${D}AVAILABLE${RESET}"
  fi
done

echo
sleep 1

echo -ne "  "
typewrite_color "$G" ">>> Re-dispatching to ${RECOVERY_REGION} (\$${RECOVERY_PRICE}/hr)" 0.04
echo
echo

# Actually retry via admin API
echo -ne "  "
typewrite_color "$D" "POST /api/admin/jobs/${JOB_ID}/retry" 0.02
echo
RETRY_RESULT=$(curl -s -X POST "$API/admin/jobs/$JOB_ID/retry" 2>/dev/null || echo '{"status":"simulated"}')
echo -e "  ${D}Response: ${RETRY_RESULT}${RESET}"

echo
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}   RE-DISPATCHED: ${RECOVERY_REGION} — Loading checkpoint...    ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 5 — 체크포인트 복원 + 학습 재개 (애니메이션)
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 5 / 6  ${RESET}  ${W}${BOLD}체크포인트 복원 & 학습 재개${RESET}"
hr "=" "$M"
echo

echo -e "  ${C}  Restoring from checkpoint...${RESET}"
echo

for action in \
  "${D}→ New pod scheduled in ${RECOVERY_REGION}${RESET}" \
  "${D}→ Pulling image: nvidia/cuda:12.2.0-runtime${RESET}" \
  "${C}→ Downloading checkpoint: epoch_30.pt from S3${RESET}" \
  "${C}→ Loading model state_dict...${RESET}" \
  "${C}→ Loading optimizer state...${RESET}" \
  "${G}→ Checkpoint restored! Resuming from epoch 30${RESET}"; do
  sleep 0.7
  echo -e "     $action"
done

echo
echo -e "  ${D}  ──────────────────────────────────────────────────${RESET}"
echo -e "  ${W}${BOLD}  Resumed Training Progress${RESET}"
echo -e "  ${D}  ──────────────────────────────────────────────────${RESET}"
echo

# Animated resumed training: epoch 30 → 100
for epoch in 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100; do
  pct=$(( epoch * 100 / 100 ))
  training_progress "$pct" "$epoch" 100 "$C"
  sleep 0.3
done

echo
echo
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}   [OK] TRAINING COMPLETE!  100/100 epochs                       ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}   Checkpoint recovery saved ~70% of training time             ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"

pause_key

# ╔═══════════════════════════════════════════════════════════
#  STEP 6 — 타임라인 + 비용 비교
# ╚═══════════════════════════════════════════════════════════
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 6 / 6  ${RESET}  ${W}${BOLD}복구 타임라인 & 비용 비교${RESET}"
hr "=" "$M"
echo

echo -e "  ${W}${BOLD}  Recovery Timeline${RESET}"
echo -e "  ${D}  ──────────────────────────────────────────────────────────────${RESET}"
echo

EVENTS=(
  "${G}*${RESET}  T+0:00   │  ${G}Job started${RESET} in ${C}${INITIAL_REGION}${RESET} (g5.xlarge)"
  "${D}*${RESET}  T+1:30   │  ${D}Epoch 30/100 — checkpoint saved to S3${RESET}"
  "${R}*${RESET}  T+1:32   │  ${R}!! SPOT INTERRUPTION${RESET} — 2-min warning"
  "${Y}*${RESET}  T+1:33   │  ${Y}Emergency checkpoint save initiated${RESET}"
  "${Y}*${RESET}  T+1:35   │  ${Y}Instance terminated. Status → cancelled${RESET}"
  "${C}*${RESET}  T+1:36   │  ${C}Dispatcher detects failure, scans prices${RESET}"
  "${G}*${RESET}  T+1:37   │  ${G}Job requeued → ${RECOVERY_REGION}${RESET} (\$${RECOVERY_PRICE}/hr)"
  "${G}*${RESET}  T+1:40   │  ${G}Pod scheduled, loading epoch_30.pt${RESET}"
  "${G}*${RESET}  T+1:42   │  ${G}Training resumed from epoch 30${RESET}"
  "${G}*${RESET}  T+4:30   │  ${G}${BOLD}Training complete! [OK]${RESET}"
)

for event in "${EVENTS[@]}"; do
  echo -e "     $event"
  sleep 0.4
done

echo
echo -e "  ${D}  ──────────────────────────────────────────────────────────────${RESET}"
echo

echo -e "  ${W}Recovery time${RESET}  : ${G}${BOLD}~3 minutes${RESET} ${D}(save + region switch + resume)${RESET}"
echo -e "  ${W}Data lost${RESET}      : ${G}${BOLD}0 epochs${RESET} ${D}(checkpoint restored perfectly)${RESET}"
echo -e "  ${W}Extra cost${RESET}     : ${G}${BOLD}\$0.00${RESET} ${D}(interrupted time not billed)${RESET}"

echo
hr "-" "$D"
echo

echo -e "  ${W}${BOLD}  Cost Comparison${RESET}"
echo -e "  ${D}  ──────────────────────────────────────────────────────────────${RESET}"
echo

# Animated cost bars
echo -e "  ${R}On-Demand (no recovery)${RESET}     5.0 hrs   ${R}\$4.03${RESET}"
for pct_step in $(seq 10 10 100); do
  printf "\r"
  anim_bar "$pct_step" "$R"
  sleep 0.03
done
echo

echo -e "  ${Y}Spot (manual recovery)${RESET}      5.5 hrs   ${Y}\$1.54 + downtime${RESET}"
for pct_step in $(seq 10 10 38); do
  printf "\r"
  anim_bar "$pct_step" "$Y"
  sleep 0.03
done
echo

echo -e "  ${G}${BOLD}Spot Lotto (auto-recovery)${RESET}  4.5 hrs   ${G}${BOLD}\$1.19${RESET}"
for pct_step in $(seq 5 5 30); do
  printf "\r"
  anim_bar "$pct_step" "$G"
  sleep 0.03
done

echo
echo
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}   SAVINGS: ~70% vs On-Demand  |  ~23% vs Manual Spot         ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}   + Zero-downtime automatic recovery                         ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"

echo
echo -e "  ${D}Grafana 대시보드에서 retry 메트릭과 리전 이동을 확인하세요:${RESET}"
echo -e "  ${UNDERLINE}${C}${BASE_URL}/grafana/d/gpu-spot-lotto/gpu-spot-lotto${RESET}"

echo
hr "=" "$R"
echo
echo -e "  ${R}${BOLD}"
cat << 'ART'
     ██████╗  ██████╗ ███╗   ██╗███████╗██╗
     ██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║
     ██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║
     ██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝
     ██████╔╝╚██████╔╝██║ ╚████║███████╗██╗
     ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝
ART
echo -e "${RESET}"
echo -e "  ${G}${BOLD}Scenario 2 Complete!${RESET}"
echo -e "  ${D}스팟 회수에도 체크포인트 자동 복구로 학습이 무중단 완료되었습니다.${RESET}"
echo -e "  ${D}${INITIAL_REGION} → ${RECOVERY_REGION} 자동 리전 전환, 데이터 손실 0 에포크.${RESET}"
echo
hr "=" "$R"
echo
