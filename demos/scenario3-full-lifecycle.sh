#!/usr/bin/env bash
# ============================================================
#  Scenario 3: End-to-End GPU Lifecycle
#
#  Seoul S3 Hub -> Spot Region FSx -> Training -> Results Sync
#  모델 업로드부터 학습, 결과 동기화까지 전체 라이프사이클 시연
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

data_flow_arrow() {
  local label="$1" color="${2:-$C}"
  echo -ne "     ${color}"
  for s in ">" ">>" ">>>" ">>>>"; do
    printf "\r     ${color}%-50s${RESET}" "$s $label"
    sleep 0.2
  done
  echo
}

# ── FULL SCREEN BANNER ─────────────────────────────────────
clear
echo
echo
echo -e "  ${C}${BOLD}"
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
echo -e "${BG_C}${W}${BOLD}$(printf '%*s' $COLS '' | tr ' ' ' ')${RESET}"
echo -e "${BG_C}${W}${BOLD}$(center 'SCENARIO 3: End-to-End GPU Lifecycle & Seoul Data Sync')${RESET}"
echo -e "${BG_C}${W}${BOLD}$(printf '%*s' $COLS '' | tr ' ' ' ')${RESET}"
echo
echo -e "  ${D}+---------------------------------------------------+${RESET}"
echo -e "  ${D}|${RESET}  Endpoint  ${D}|${RESET} ${C}${BASE_URL}${RESET}"
echo -e "  ${D}|${RESET}  Hub       ${D}|${RESET} ${W}Seoul (ap-northeast-2)${RESET} S3 + Redis"
echo -e "  ${D}|${RESET}  Regions   ${D}|${RESET} us-east-1, us-east-2, us-west-2"
echo -e "  ${D}|${RESET}  Storage   ${D}|${RESET} ${G}S3 Hub -> FSx Lustre (auto-sync)${RESET}"
echo -e "  ${D}|${RESET}  Scenario  ${D}|${RESET} Upload -> Train -> Sync -> Download"
echo -e "  ${D}+---------------------------------------------------+${RESET}"
echo
echo -e "  ${W}${BOLD}  [About]${RESET}"
echo -e "  ${D}  Seoul S3 Hub를 중심으로 모델 업로드부터 GPU 학습,${RESET}"
echo -e "  ${D}  결과 동기화까지 전체 데이터 라이프사이클을 시연합니다.${RESET}"
echo -e "  ${D}  FSx Lustre의 auto-import/export로 Seoul S3와 Spot 리전 간${RESET}"
echo -e "  ${D}  데이터가 자동 동기화되어 별도 복사 작업이 필요 없습니다.${RESET}"
echo
echo -e "  ${W}${BOLD}  [Steps]${RESET}"
echo -e "  ${C}  1.${RESET} Hub-and-Spoke 아키텍처       ${D}-- Seoul S3 + 3 FSx 리전 구조${RESET}"
echo -e "  ${C}  2.${RESET} Seoul S3 모델 업로드         ${D}-- Presigned URL로 S3 직접 업로드${RESET}"
echo -e "  ${C}  3.${RESET} Spot 가격 스캔               ${D}-- 3개 리전 실시간 가격 비교${RESET}"
echo -e "  ${C}  4.${RESET} FSx Auto-Import & 작업 배치  ${D}-- S3 -> FSx 자동 동기화 + Pod${RESET}"
echo -e "  ${C}  5.${RESET} GPU 학습 + 체크포인트        ${D}-- 50 epoch 학습, 매 10 epoch 저장${RESET}"
echo -e "  ${C}  6.${RESET} 결과 Seoul S3 동기화         ${D}-- FSx auto-export -> Seoul S3${RESET}"
echo -e "  ${C}  7.${RESET} 비용 & 아키텍처 요약         ${D}-- On-Demand vs Spot + 핵심 이점${RESET}"

pause_key

# ================================================================
#  STEP 1 -- Architecture Overview
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 1 / 7  ${RESET}  ${W}${BOLD}Hub-and-Spoke Architecture${RESET}"
hr "=" "$M"
echo

echo -e "  ${W}${BOLD}  GPU Spot Lotto: Seoul-Centric Data Architecture${RESET}"
echo
echo -e "  ${D}  All data lives in Seoul S3. Spot regions cache via FSx Lustre.${RESET}"
echo

echo -e "  ${Y}                    +==========================+${RESET}"
echo -e "  ${Y}                    |  ${W}Seoul (ap-northeast-2)${RESET}  ${Y}|${RESET}"
echo -e "  ${Y}                    |  ${C}S3 Hub Bucket${RESET}           ${Y}|${RESET}"
echo -e "  ${Y}                    |  ${D}models/ datasets/      ${RESET} ${Y}|${RESET}"
echo -e "  ${Y}                    |  ${D}checkpoints/ results/  ${RESET} ${Y}|${RESET}"
echo -e "  ${Y}                    |  ${M}Redis + API Server${RESET}     ${Y}|${RESET}"
echo -e "  ${Y}                    +============+==+==========+${RESET}"
echo -e "  ${Y}                       auto-sync | |  | auto-sync${RESET}"
echo -e "  ${Y}               +---------+  +----+ +----+  +---------+${RESET}"
echo -e "  ${Y}               V          V          V          V${RESET}"
echo -e "  ${C}       +==============+ +==============+ +==============${RESET}+"
echo -e "  ${C}       | ${W}us-east-1${RESET}    ${C}| | ${W}us-east-2${RESET}    ${C}| | ${W}us-west-2${RESET}    ${C}|${RESET}"
echo -e "  ${C}       | ${D}FSx Lustre${RESET}   ${C}| | ${D}FSx Lustre${RESET}   ${C}| | ${D}FSx Lustre${RESET}   ${C}|${RESET}"
echo -e "  ${C}       | ${D}EKS + GPU${RESET}    ${C}| | ${D}EKS + GPU${RESET}    ${C}| | ${D}EKS + GPU${RESET}    ${C}|${RESET}"
echo -e "  ${C}       +==============+ +==============+ +==============${RESET}+"
echo
echo -e "  ${D}  [Data Flow]${RESET}"
echo -e "  ${G}  Upload${RESET}  : User -> Seoul S3       (Presigned URL)"
echo -e "  ${C}  Import${RESET}  : Seoul S3 -> FSx Lustre  (Auto-Import, seconds)"
echo -e "  ${Y}  Train${RESET}   : GPU Pod reads FSx, writes results"
echo -e "  ${M}  Export${RESET}  : FSx Lustre -> Seoul S3  (Auto-Export, seconds)"
echo -e "  ${G}  Access${RESET}  : Results available in Seoul S3"

pause_key

# ================================================================
#  STEP 2 -- Model Upload to Seoul S3
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 2 / 7  ${RESET}  ${W}${BOLD}Seoul S3 Hub: Model Upload${RESET}"
hr "=" "$M"
echo

echo -e "  ${D}Uploading ML model to Seoul S3 Hub via Presigned URL...${RESET}"
echo
echo -e "  ${W}  +----------------------------------------------+${RESET}"
echo -e "  ${W}  |${RESET}                                              ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Bucket${RESET}   s3://gpu-lotto-dev-data/          ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Region${RESET}   ap-northeast-2 (Seoul)            ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Prefix${RESET}   models/dev-user/                  ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}File${RESET}     sdxl-lora-base.safetensors        ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Size${RESET}     2.4 GB                            ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Encrypt${RESET}  KMS (aws:kms)                     ${W}|${RESET}"
echo -e "  ${W}  |${RESET}                                              ${W}|${RESET}"
echo -e "  ${W}  +----------------------------------------------+${RESET}"
echo

echo -ne "  "
typewrite_color "$C" "POST /api/upload/presign" 0.04
echo
echo

# Request presigned URL
curl -s -X POST "$API/upload/presign" \
  -H "Content-Type: application/json" \
  -d '{"filename":"sdxl-lora-base.safetensors","prefix":"models"}' > /tmp/gpu_presign.json &
spinner $! "Requesting presigned upload URL from Seoul API"

PRESIGN_RESULT=$(cat /tmp/gpu_presign.json 2>/dev/null || echo '{}')
echo -e "  ${D}Response: $(echo "$PRESIGN_RESULT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if 'url' in d:
    print(f'Presigned URL generated (expires in 3600s)')
else:
    print(json.dumps(d)[:80])
" 2>/dev/null || echo "simulated")${RESET}"

echo
echo -e "  ${D}  Simulating upload progress:${RESET}"
for pct in 10 25 50 75 90 100; do
  printf "\r"
  anim_bar "$pct" "$C" "sdxl-lora-base.safetensors"
  sleep 0.3
done
echo

echo -e "  ${BG_G}${W}${BOLD}  MODEL UPLOADED  ${RESET}"
echo -e "  ${D}  s3://gpu-lotto-dev-data/models/dev-user/sdxl-lora-base.safetensors${RESET}"

pause_key

# ================================================================
#  STEP 3 -- Spot Price Scan & Region Selection
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 3 / 7  ${RESET}  ${W}${BOLD}Spot Price Scan & Cheapest Region${RESET}"
hr "=" "$M"
echo

echo -e "  ${D}Price Watcher collects live Spot prices every 60 seconds...${RESET}"
echo

curl -s "$API/prices" > /tmp/gpu_prices3.json &
spinner $! "GET /api/prices (live from AWS EC2 API)"
echo

PRICES_RAW=$(cat /tmp/gpu_prices3.json)
CHEAPEST_REGION="us-east-2"
CHEAPEST_PRICE="0.1999"
CHEAPEST_TYPE="g6.xlarge"

if echo "$PRICES_RAW" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  echo "$PRICES_RAW" | python3 -c "
import sys, json
data = json.load(sys.stdin)
prices = sorted(data.get('prices', []), key=lambda x: x['price'])
cheapest = prices[0]['price'] if prices else 0

print('  \033[1;37m  %-14s  %-13s  %-10s  %s\033[0m' % ('REGION', 'INSTANCE', 'PRICE/HR', 'BAR'))
print('  \033[0;90m  %-14s  %-13s  %-10s  %s\033[0m' % ('-'*14, '-'*13, '-'*10, '-'*20))

for p in prices[:12]:
    r, t, pr = p['region'], p['instance_type'], p['price']
    is_best = (pr == cheapest)
    bar_len = int(min(pr / 6.0, 1.0) * 20)
    bar = '#' * bar_len + '.' * (20 - bar_len)
    if is_best:
        marker = '\033[42m\033[1;37m BEST \033[0m'
        pc = '\033[1;32m'
    else:
        marker = '     '
        pc = '\033[0m'
    print(f'  {pc}  {r:<14}\033[0m  {t:<13}  {pc}\${pr:<9.4f}\033[0m  \033[0;32m{bar}\033[0m {marker}')
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
fi

echo
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}   CHEAPEST: ${CHEAPEST_REGION} -- \$${CHEAPEST_PRICE}/hr (${CHEAPEST_TYPE})         ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"

pause_key

# ================================================================
#  STEP 4 -- FSx Auto-Import & Job Dispatch
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 4 / 7  ${RESET}  ${W}${BOLD}FSx Auto-Import & Job Dispatch${RESET}"
hr "=" "$M"
echo

echo -e "  ${W}${BOLD}  Data Sync: Seoul S3 -> ${CHEAPEST_REGION} FSx Lustre${RESET}"
echo -e "  ${D}  --------------------------------------------------------${RESET}"
echo

echo -e "  ${Y}  Seoul S3 Hub                      ${CHEAPEST_REGION} FSx Lustre${RESET}"
echo -e "  ${D}  +-------------------+              +-------------------+${RESET}"
echo -e "  ${D}  | models/           |              | /data/models/     |${RESET}"
echo -e "  ${D}  |   sdxl-lora-base  | ${C}--auto--->  ${RESET}${D}|   sdxl-lora-base  |${RESET}"
echo -e "  ${D}  | datasets/         |  ${C}import${RESET}    ${D}| /data/datasets/   |${RESET}"
echo -e "  ${D}  |   imagenet-100k   | ${C}--auto--->  ${RESET}${D}|   imagenet-100k   |${RESET}"
echo -e "  ${D}  +-------------------+              +-------------------+${RESET}"
echo

echo -e "  ${D}  FSx Auto-Import triggers on first read access:${RESET}"
for item in \
  "${C}[SYNC]${RESET} models/dev-user/sdxl-lora-base.safetensors  ${D}(2.4 GB)${RESET}" \
  "${C}[SYNC]${RESET} datasets/imagenet-100k/                     ${D}(12.0 GB)${RESET}" \
  "${G}[DONE]${RESET} Import complete. Data cached in FSx SSD."; do
  sleep 0.8
  echo -e "     $item"
done

echo
hr "-" "$D"
echo

echo -e "  ${W}${BOLD}  Dispatching Job to ${CHEAPEST_REGION}${RESET}"
echo
echo -e "  ${W}  +----------------------------------------------+${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Image${RESET}       nvidia/cuda:12.2.0-runtime       ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Task${RESET}        LoRA fine-tuning (SDXL)           ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Instance${RESET}    ${CHEAPEST_TYPE} (Spot)                   ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Region${RESET}      ${G}${CHEAPEST_REGION}${RESET} (\$${CHEAPEST_PRICE}/hr)            ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Storage${RESET}     FSx Lustre (auto-sync to S3)      ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Checkpoint${RESET}  ${G}Enabled${RESET} (every 10 epochs)         ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Mounts${RESET}      /data/models (RO), /data/results  ${W}|${RESET}"
echo -e "  ${W}  +----------------------------------------------+${RESET}"
echo

JOB_PAYLOAD='{
  "image": "nvidia/cuda:12.2.0-runtime-ubuntu22.04",
  "command": ["python3", "-c", "import time; print(\"Loading model from /data/models...\"); time.sleep(5); print(\"Fine-tuning SDXL LoRA...\"); [print(f\"Epoch {e}/50\") or time.sleep(2) for e in range(50)]; print(\"Saving results to /data/results...\"); print(\"Done!\")"],
  "instance_type": "'"$CHEAPEST_TYPE"'",
  "gpu_type": "L4",
  "gpu_count": 1,
  "storage_mode": "fsx",
  "checkpoint_enabled": true
}'

# Snapshot existing job IDs before submission
BEFORE_IDS=$(curl -s "$API/admin/jobs" | python3 -c "
import sys, json
jobs = json.load(sys.stdin).get('jobs', [])
print(' '.join(j['job_id'] for j in jobs))
" 2>/dev/null || echo "")

curl -s -X POST "$API/jobs" \
  -H "Content-Type: application/json" \
  -d "$JOB_PAYLOAD" > /tmp/gpu_job_result3.json &
spinner $! "POST /api/jobs (dispatch to ${CHEAPEST_REGION})"

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
    # Pick the newest by created_at
    best = max(new, key=lambda j: j.get('created_at', '0'))
    print(best['job_id'])
" 2>/dev/null || echo "")
  [ -n "$JOB_ID" ] && break
  printf "\r  ${C}|${RESET} Waiting for dispatcher... (%d/10)" "$attempt"
done
[ -z "$JOB_ID" ] && JOB_ID="demo-$(date +%s)"

echo
echo -e "  ${BG_G}${W}  JOB DISPATCHED  ${RESET}"
echo -e "  ${W}  Job ID${RESET}  : ${G}${BOLD}${JOB_ID}${RESET}"
echo -e "  ${W}  Region${RESET}  : ${C}${CHEAPEST_REGION}${RESET}"
echo -e "  ${W}  Storage${RESET} : FSx Lustre (Seoul S3 backed)"

pause_key

# ================================================================
#  STEP 5 -- Training + Checkpoint Progress
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 5 / 7  ${RESET}  ${W}${BOLD}GPU Training in ${CHEAPEST_REGION}${RESET}"
hr "=" "$M"
echo

# Poll for actual status
for i in $(seq 1 4); do
  JOB_RAW=$(curl -s "$API/jobs/$JOB_ID" 2>/dev/null || echo '{}')
  STATUS=$(echo "$JOB_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
  REGION=$(echo "$JOB_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('region','-'))" 2>/dev/null || echo "-")

  case "$STATUS" in
    queued)    badge="${BG_Y}${W} QUEUED  ${RESET}" ;;
    running)   badge="${BG_G}${W} RUNNING ${RESET}" ;;
    *)         badge="${BG_D}${W} ${STATUS^^} ${RESET}" ;;
  esac
  printf "\r  ${badge}  Job: ${D}%.8s${RESET}  Region: ${C}%-12s${RESET}" "$JOB_ID" "$REGION"
  [[ "$STATUS" == "running" ]] && break
  sleep 3
done
echo
echo

echo -e "  ${W}${BOLD}  Training Progress${RESET}"
echo -e "  ${D}  --------------------------------------------------------${RESET}"
echo

# Simulated training with checkpoints
for epoch in 0 5 10 15 20 25 30 35 40 45 50; do
  pct=$(( epoch * 100 / 50 ))
  local_width=30
  local_filled=$(( pct * local_width / 100 ))
  local_empty=$(( local_width - local_filled ))

  printf "\r  ${G}Epoch %3d/%d${RESET}  ${G}" "$epoch" 50
  for ((j=0; j<local_filled; j++)); do printf '#'; done
  printf "${D}"
  for ((j=0; j<local_empty; j++)); do printf '.'; done
  printf "${RESET} ${D}%3d%%${RESET}" "$pct"

  if (( epoch > 0 && epoch % 10 == 0 )); then
    echo
    echo -e "     ${C}>> Checkpoint: epoch_${epoch}.pt -> /data/checkpoints/${RESET}"
    echo -e "     ${D}   FSx auto-export -> s3://gpu-lotto-dev-data/checkpoints/${JOB_ID}/epoch_${epoch}.pt${RESET}"
  fi

  sleep 0.3
done

echo
echo
echo -e "  ${BG_G}${W}${BOLD}  TRAINING COMPLETE  ${RESET}  50/50 epochs"
echo
echo -e "  ${D}  Results written to: /data/results/${JOB_ID}/${RESET}"
echo -e "  ${D}  - lora_weights.safetensors (320 MB)${RESET}"
echo -e "  ${D}  - training_log.json${RESET}"
echo -e "  ${D}  - sample_outputs/ (12 images)${RESET}"

pause_key

# ================================================================
#  STEP 6 -- FSx Auto-Export: Results -> Seoul S3
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 6 / 7  ${RESET}  ${W}${BOLD}Results Sync: ${CHEAPEST_REGION} -> Seoul S3${RESET}"
hr "=" "$M"
echo

echo -e "  ${W}${BOLD}  FSx Auto-Export: Results back to Seoul${RESET}"
echo -e "  ${D}  --------------------------------------------------------${RESET}"
echo

echo -e "  ${C}  ${CHEAPEST_REGION} FSx Lustre              Seoul S3 Hub${RESET}"
echo -e "  ${D}  +-------------------+              +-------------------+${RESET}"
echo -e "  ${D}  | /data/results/    |              | results/          |${RESET}"
echo -e "  ${D}  |   lora_weights    |              |  ${CHEAPEST_REGION}/     |${RESET}"
echo -e "  ${D}  |   training_log    |  ${M}--export--> ${RESET}${D}|    ${JOB_ID:0:8}.../  |${RESET}"
echo -e "  ${D}  |   sample_outputs/ |  ${M}auto-sync${RESET}  ${D}|     lora_weights  |${RESET}"
echo -e "  ${D}  +-------------------+              +-------------------+${RESET}"
echo

echo -e "  ${D}  FSx Auto-Export Policy: NEW, CHANGED, DELETED${RESET}"
echo

for item in \
  "${M}[EXPORT]${RESET} lora_weights.safetensors        ${D}(320 MB)  ..." \
  "${M}[EXPORT]${RESET} training_log.json               ${D}(48 KB)   ..." \
  "${M}[EXPORT]${RESET} sample_outputs/img_001.png       ${D}(2.1 MB)  ..." \
  "${M}[EXPORT]${RESET} sample_outputs/img_002.png       ${D}(1.9 MB)  ..." \
  "${M}[EXPORT]${RESET} sample_outputs/ (10 more files)  ${D}(18 MB)   ..."; do
  sleep 0.6
  echo -e "     $item"
done

sleep 0.5
echo
echo -e "  ${G}  [OK] All results exported to Seoul S3${RESET}"
echo

echo -e "  ${W}  Final S3 paths (Seoul, ap-northeast-2):${RESET}"
echo
echo -e "  ${D}  s3://gpu-lotto-dev-data/${RESET}"
echo -e "  ${D}    +-- results/${RESET}"
echo -e "  ${D}    |   +-- ${G}${CHEAPEST_REGION}/${RESET}${D}                     <-- region prefix${RESET}"
echo -e "  ${D}    |       +-- ${W}${JOB_ID:0:8}.../${RESET}"
echo -e "  ${D}    |           +-- lora_weights.safetensors${RESET}"
echo -e "  ${D}    |           +-- training_log.json${RESET}"
echo -e "  ${D}    |           +-- sample_outputs/${RESET}"
echo -e "  ${D}    +-- checkpoints/${RESET}"
echo -e "  ${D}        +-- ${JOB_ID:0:8}.../${RESET}"
echo -e "  ${D}            +-- epoch_10.pt  ${Y}(7-day TTL)${RESET}"
echo -e "  ${D}            +-- epoch_20.pt  ${Y}(7-day TTL)${RESET}"
echo -e "  ${D}            +-- epoch_30.pt  ${Y}(7-day TTL)${RESET}"
echo -e "  ${D}            +-- epoch_40.pt  ${Y}(7-day TTL)${RESET}"
echo -e "  ${D}            +-- epoch_50.pt  ${Y}(7-day TTL)${RESET}"

echo
echo -e "  ${D}  Results -> GLACIER after 90 days | Checkpoints auto-delete in 7 days${RESET}"

pause_key

# ================================================================
#  STEP 7 -- Summary: Cost + Architecture
# ================================================================
clear
echo
echo -e "  ${BG_M}${W}${BOLD}  STEP 7 / 7  ${RESET}  ${W}${BOLD}Summary: Cost & Architecture${RESET}"
hr "=" "$M"
echo

echo -e "  ${W}${BOLD}  End-to-End Lifecycle Completed${RESET}"
echo -e "  ${D}  --------------------------------------------------------${RESET}"
echo

# Timeline
EVENTS=(
  "${G}*${RESET}  T+0:00   |  ${G}Model uploaded${RESET} to Seoul S3 (Presigned URL)"
  "${C}*${RESET}  T+0:01   |  ${C}Spot prices scanned${RESET} across 3 regions"
  "${G}*${RESET}  T+0:02   |  ${G}Job dispatched${RESET} to ${C}${CHEAPEST_REGION}${RESET} (\$${CHEAPEST_PRICE}/hr)"
  "${C}*${RESET}  T+0:03   |  ${C}FSx auto-import${RESET}: Seoul S3 -> ${CHEAPEST_REGION} FSx"
  "${Y}*${RESET}  T+0:05   |  ${Y}Training started${RESET}: 50 epochs, checkpoints every 10"
  "${M}*${RESET}  T+2:30   |  ${M}Training complete${RESET}: results written to FSx"
  "${M}*${RESET}  T+2:31   |  ${M}FSx auto-export${RESET}: ${CHEAPEST_REGION} FSx -> Seoul S3"
  "${G}*${RESET}  T+2:32   |  ${G}${BOLD}Results available in Seoul S3${RESET}"
)

for event in "${EVENTS[@]}"; do
  echo -e "     $event"
  sleep 0.3
done

echo
hr "-" "$D"
echo

echo -e "  ${W}${BOLD}  Cost Analysis${RESET}"
echo

OD_PRICE="0.8050"
SPOT_PRICE="${CHEAPEST_PRICE}"
HOURS="2.5"
OD_COST=$(python3 -c "print(f'{float(\"$OD_PRICE\")*float(\"$HOURS\"):.2f}')")
SPOT_COST=$(python3 -c "print(f'{float(\"$SPOT_PRICE\")*float(\"$HOURS\"):.2f}')")
SAVINGS=$(python3 -c "print(f'{(1 - float(\"$SPOT_PRICE\")/float(\"$OD_PRICE\"))*100:.0f}')")

echo -e "  ${R}On-Demand${RESET}     \$${OD_PRICE}/hr x ${HOURS}h = ${R}\$${OD_COST}${RESET}"
for pct_step in $(seq 10 10 100); do
  printf "\r"
  anim_bar "$pct_step" "$R"
  sleep 0.02
done
echo

echo -e "  ${G}Spot Lotto${RESET}    \$${SPOT_PRICE}/hr x ${HOURS}h = ${G}${BOLD}\$${SPOT_COST}${RESET}"
SPOT_PCT=$(python3 -c "print(int(float('$SPOT_PRICE')/float('$OD_PRICE')*100))")
for pct_step in $(seq 5 5 $SPOT_PCT); do
  printf "\r"
  anim_bar "$pct_step" "$G"
  sleep 0.02
done

echo
echo
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}   SAVINGS: ~${SAVINGS}% vs On-Demand                               ${RESET}"
echo -e "  ${BG_G}${W}${BOLD}                                                              ${RESET}"

echo
hr "-" "$D"
echo

echo -e "  ${W}${BOLD}  Key Architecture Benefits${RESET}"
echo
echo -e "  ${G}[1]${RESET} ${W}Seoul S3 Hub${RESET}        : Single source of truth for all data"
echo -e "  ${G}[2]${RESET} ${W}FSx Auto-Sync${RESET}       : Zero-copy data movement, seconds latency"
echo -e "  ${G}[3]${RESET} ${W}Multi-Region Spot${RESET}   : Always use cheapest GPU across 3 regions"
echo -e "  ${G}[4]${RESET} ${W}Checkpoint Safety${RESET}   : Auto-export to S3, survives spot reclaim"
echo -e "  ${G}[5]${RESET} ${W}Lifecycle Mgmt${RESET}      : Results -> GLACIER (90d), Checkpoints TTL (7d)"
echo -e "  ${G}[6]${RESET} ${W}Zero Idle Cost${RESET}      : Karpenter scales to 0 when no jobs"
echo

echo -e "  ${D}  Dashboard: ${UNDERLINE}${C}${BASE_URL}${RESET}"
echo -e "  ${D}  Grafana:   ${UNDERLINE}${C}${BASE_URL}/grafana/d/gpu-spot-lotto/gpu-spot-lotto${RESET}"
echo

hr "=" "$C"
echo
echo -e "  ${C}${BOLD}"
cat << 'ART'
     ██████╗  ██████╗ ███╗   ██╗███████╗██╗
     ██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║
     ██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║
     ██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝
     ██████╔╝╚██████╔╝██║ ╚████║███████╗██╗
     ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝
ART
echo -e "${RESET}"
echo -e "  ${G}${BOLD}Scenario 3 Complete!${RESET}"
echo -e "  ${D}Seoul S3 Hub 중심의 데이터 라이프사이클이 완료되었습니다.${RESET}"
echo -e "  ${D}모델 업로드 -> ${CHEAPEST_REGION} GPU 학습 -> 결과 Seoul 동기화 -> 비용 ${SAVINGS}% 절감${RESET}"
echo
hr "=" "$C"
echo
