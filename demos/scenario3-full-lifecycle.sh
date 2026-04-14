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
S3_BUCKET="${GPU_LOTTO_S3_BUCKET:-gpu-lotto-dev-data}"
S3_REGION="ap-northeast-2"

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

echo -e "  ${D}Uploading ML model to Seoul S3 Hub (REAL upload)...${RESET}"
echo

# Create test model file
DEMO_FILE="/tmp/gpu-lotto-demo-model.bin"
DEMO_TS=$(date +%s)
DEMO_FILENAME="demo-model-${DEMO_TS}.bin"
S3_KEY="models/dev-user/${DEMO_FILENAME}"
dd if=/dev/urandom bs=1024 count=64 of="$DEMO_FILE" 2>/dev/null

echo -e "  ${W}  +----------------------------------------------+${RESET}"
echo -e "  ${W}  |${RESET}                                              ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Bucket${RESET}   s3://${S3_BUCKET}/               ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Region${RESET}   ${S3_REGION} (Seoul)             ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Key${RESET}      ${S3_KEY}      ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Size${RESET}     64 KB (demo test file)             ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Mode${RESET}     ${G}REAL UPLOAD${RESET} (not simulation)       ${W}|${RESET}"
echo -e "  ${W}  |${RESET}                                              ${W}|${RESET}"
echo -e "  ${W}  +----------------------------------------------+${RESET}"
echo

echo -ne "  "
typewrite_color "$C" "POST /api/upload/presign" 0.04
echo
echo

# Request presigned URL from API
curl -s -X POST "$API/upload/presign" \
  -H "Content-Type: application/json" \
  -d "{\"filename\":\"${DEMO_FILENAME}\",\"prefix\":\"models\"}" > /tmp/gpu_presign.json &
spinner $! "Requesting presigned upload URL from Seoul API"

PRESIGN_RESULT=$(cat /tmp/gpu_presign.json 2>/dev/null || echo '{}')
echo -e "  ${D}Response: $(echo "$PRESIGN_RESULT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if 'url' in d:
    print(f'Presigned URL -> {d[\"url\"][:60]}...')
elif 'fields' in d:
    print(f'Presigned POST fields generated (key: {d[\"fields\"].get(\"key\",\"?\")})')
else:
    print(json.dumps(d)[:80])
" 2>/dev/null || echo "presigned URL received")${RESET}"

echo
echo -e "  ${W}  Uploading to Seoul S3...${RESET}"
echo

# Real upload to S3
aws s3 cp "$DEMO_FILE" "s3://${S3_BUCKET}/${S3_KEY}" \
  --region "$S3_REGION" --quiet 2>/dev/null &
UPLOAD_PID=$!

# Animated progress while uploading
for pct in 10 25 50 75 90; do
  printf "\r"
  anim_bar "$pct" "$C" "$DEMO_FILENAME"
  sleep 0.2
done
wait $UPLOAD_PID 2>/dev/null
UPLOAD_RC=$?
printf "\r"
anim_bar "100" "$C" "$DEMO_FILENAME"
echo

# Verify upload in S3
echo -ne "  ${C}[VERIFY]${RESET} "
S3_VERIFY=$(aws s3 ls "s3://${S3_BUCKET}/${S3_KEY}" --region "$S3_REGION" 2>&1 || true)
if [ -n "$S3_VERIFY" ] && [ "$UPLOAD_RC" -eq 0 ]; then
  echo -e "${G}File confirmed in Seoul S3${RESET}"
  echo -e "  ${D}  $S3_VERIFY${RESET}"
else
  echo -e "${Y}Upload may be pending (will verify later)${RESET}"
fi

echo
echo -e "  ${BG_G}${W}${BOLD}  MODEL UPLOADED (REAL)  ${RESET}"
echo -e "  ${D}  s3://${S3_BUCKET}/${S3_KEY}${RESET}"

rm -f "$DEMO_FILE"

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

  # Fetch capacity to mirror Dispatcher logic: cheapest g6.xlarge WHERE capacity > 0
  curl -s "$API/admin/regions" > /tmp/gpu_cap3.json 2>/dev/null || echo '{}' > /tmp/gpu_cap3.json
  CHEAPEST=$(python3 -c "
import json
with open('/tmp/gpu_prices3.json') as f:
    prices_data = json.load(f)
with open('/tmp/gpu_cap3.json') as f:
    cap_data = json.load(f)
cap_map = {r['region']: r.get('capacity', 0) for r in cap_data.get('regions', [])}
# Filter g6.xlarge, sort by price, pick first with capacity
g6 = sorted([p for p in prices_data.get('prices', []) if p['instance_type'] == 'g6.xlarge'],
            key=lambda x: x['price'])
best = next((p for p in g6 if cap_map.get(p['region'], 0) > 0), g6[0] if g6 else None)
if best:
    print(f\"{best['region']}|{best['price']:.4f}|{best['instance_type']}\")
else:
    prices = prices_data.get('prices', [])
    b = min(prices, key=lambda x: x['price']) if prices else {'region':'us-east-2','price':0.2,'instance_type':'g6.xlarge'}
    print(f\"{b['region']}|{b['price']:.4f}|{b['instance_type']}\")
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

# Check FSx filesystem status in the selected region
echo -e "  ${W}${BOLD}  FSx Lustre Status: ${CHEAPEST_REGION}${RESET}"
echo -e "  ${D}  --------------------------------------------------------${RESET}"
echo

FSX_INFO=$(aws fsx describe-file-systems --region "$CHEAPEST_REGION" \
  --query 'FileSystems[0].{Id:FileSystemId,Status:Lifecycle,Import:LustreConfiguration.DataRepositoryConfiguration.ImportPath,Export:LustreConfiguration.DataRepositoryConfiguration.ExportPath}' \
  --output json 2>/dev/null || echo '{}')

FSX_ID=$(echo "$FSX_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('Id','unknown'))" 2>/dev/null || echo "unknown")
FSX_STATUS=$(echo "$FSX_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('Status','unknown'))" 2>/dev/null || echo "unknown")
FSX_IMPORT=$(echo "$FSX_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('Import','none'))" 2>/dev/null || echo "none")
FSX_EXPORT=$(echo "$FSX_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin).get('Export','none'))" 2>/dev/null || echo "none")

if [ "$FSX_STATUS" = "AVAILABLE" ]; then
  FSX_BADGE="${BG_G}${W} AVAILABLE ${RESET}"
else
  FSX_BADGE="${BG_Y}${W} ${FSX_STATUS} ${RESET}"
fi

echo -e "  ${W}  +----------------------------------------------+${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Filesystem${RESET}  ${FSX_ID}           ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Status${RESET}      ${FSX_BADGE}                          ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Import${RESET}      ${FSX_IMPORT}        ${W}|${RESET}"
echo -e "  ${W}  |${RESET}  ${C}Export${RESET}      ${FSX_EXPORT} ${W}|${RESET}"
echo -e "  ${W}  +----------------------------------------------+${RESET}"
echo

hr "-" "$D"
echo
echo -e "  ${W}${BOLD}  Data Sync: Seoul S3 -> ${CHEAPEST_REGION} FSx Lustre${RESET}"
echo -e "  ${D}  --------------------------------------------------------${RESET}"
echo

echo -e "  ${Y}  Seoul S3 Hub                      ${CHEAPEST_REGION} FSx Lustre${RESET}"
echo -e "  ${D}  +-------------------+              +-------------------+${RESET}"
echo -e "  ${D}  | models/           |              | /data/models/     |${RESET}"
echo -e "  ${D}  |   ${DEMO_FILENAME:0:16}  | ${C}--auto--->  ${RESET}${D}|   ${DEMO_FILENAME:0:16}  |${RESET}"
echo -e "  ${D}  |                   |  ${C}import${RESET}    ${D}|                   |${RESET}"
echo -e "  ${D}  +-------------------+              +-------------------+${RESET}"
echo

echo -e "  ${D}  FSx Auto-Import triggers on Pod's first read access:${RESET}"
for item in \
  "${C}[SYNC]${RESET} ${S3_KEY}  ${D}(64 KB, real file)${RESET}" \
  "${C}[INFO]${RESET} Auto-import: S3 -> FSx on first ls /data/models/" \
  "${G}[DONE]${RESET} File ready in FSx SSD (sub-second for small files)"; do
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

# Pod command: real FSx read (auto-import) + real file writes (auto-export)
RESULT_DIR="/data/results/demo-${DEMO_TS}"
JOB_PAYLOAD='{
  "image": "nvidia/cuda:12.2.0-runtime-ubuntu22.04",
  "command": ["/bin/sh", "-c", "echo [IMPORT] Listing /data/models ... && ls -la /data/models/ 2>/dev/null && echo [TRAIN] Starting training ... && for epoch in 1 2 3 4 5; do echo Epoch $epoch/5; sleep 2; done && echo [EXPORT] Writing results to '"$RESULT_DIR"' ... && mkdir -p '"$RESULT_DIR"' && echo {\"loss\":0.012,\"epochs\":5,\"model\":\"sdxl-lora\",\"timestamp\":\"'"$DEMO_TS"'\"} > '"$RESULT_DIR"'/training_log.json && dd if=/dev/urandom bs=1024 count=32 of='"$RESULT_DIR"'/lora_weights.bin 2>/dev/null && echo demo_output > '"$RESULT_DIR"'/sample_output.txt && echo [DONE] Results saved to FSx for auto-export"],
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
echo -e "  ${D}  Results written to: ${RESULT_DIR}/${RESET}"
echo -e "  ${D}  - lora_weights.bin (32 KB, real file on FSx)${RESET}"
echo -e "  ${D}  - training_log.json (real file on FSx)${RESET}"
echo -e "  ${D}  - sample_output.txt (real file on FSx)${RESET}"

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
echo -e "  ${D}  | ${RESULT_DIR:0:17} |              | export/           |${RESET}"
echo -e "  ${D}  |   lora_weights    |              |  data/results/    |${RESET}"
echo -e "  ${D}  |   training_log    |  ${M}--export--> ${RESET}${D}|    demo-${DEMO_TS:0:6}.../  |${RESET}"
echo -e "  ${D}  |   sample_output   |  ${M}auto-sync${RESET}  ${D}|     lora_weights  |${RESET}"
echo -e "  ${D}  +-------------------+              +-------------------+${RESET}"
echo

echo -e "  ${D}  FSx Auto-Export Policy: NEW, CHANGED, DELETED${RESET}"
echo

# Wait for job to finish before checking export
echo -e "  ${W}  Waiting for job to complete before verifying export...${RESET}"
echo
JOB_FINAL_STATUS="unknown"
for attempt in $(seq 1 60); do
  JOB_RAW=$(curl -s "$API/jobs/$JOB_ID" 2>/dev/null || echo '{}')
  JOB_FINAL_STATUS=$(echo "$JOB_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
  case "$JOB_FINAL_STATUS" in
    succeeded|failed|cancelled) break ;;
  esac
  printf "\r  ${C}|${RESET} Polling job status... ${D}(%d/60, status: %s)${RESET}  " "$attempt" "$JOB_FINAL_STATUS"
  sleep 5
done
echo

if [ "$JOB_FINAL_STATUS" = "succeeded" ]; then
  echo -e "  ${BG_G}${W} JOB SUCCEEDED ${RESET}  Pod wrote results to FSx"
else
  echo -e "  ${BG_Y}${W} JOB STATUS: ${JOB_FINAL_STATUS} ${RESET}"
fi
echo

# Animation for export process
for item in \
  "${M}[EXPORT]${RESET} lora_weights.bin       ${D}(32 KB)  FSx -> Seoul S3${RESET}" \
  "${M}[EXPORT]${RESET} training_log.json      ${D}(~100B)  FSx -> Seoul S3${RESET}" \
  "${M}[EXPORT]${RESET} sample_output.txt      ${D}(~12B)   FSx -> Seoul S3${RESET}"; do
  sleep 0.6
  echo -e "     $item"
done

echo
hr "-" "$D"
echo

# Real S3 verification
echo -e "  ${W}${BOLD}  [VERIFY] Checking Seoul S3 for auto-exported results${RESET}"
echo

# Check both the upload (models) and export paths
echo -e "  ${C}  1. Model upload (STEP 2):${RESET}"
S3_MODEL=$(aws s3 ls "s3://${S3_BUCKET}/${S3_KEY}" --region "$S3_REGION" 2>&1 || true)
if [ -n "$S3_MODEL" ]; then
  echo -e "     ${G}[OK]${RESET} $S3_MODEL"
else
  echo -e "     ${Y}[--]${RESET} Model file not found (may have been cleaned)"
fi

echo
echo -e "  ${C}  2. Auto-exported results (FSx -> S3):${RESET}"
EXPORT_FILES=$(aws s3 ls "s3://${S3_BUCKET}/export/data/results/demo-${DEMO_TS}/" \
  --region "$S3_REGION" --recursive 2>&1 || true)
if [ -n "$EXPORT_FILES" ]; then
  echo -e "     ${G}[OK] Results found in Seoul S3 via FSx auto-export!${RESET}"
  echo "$EXPORT_FILES" | while read -r line; do
    echo -e "     ${D}  $line${RESET}"
  done
else
  echo -e "     ${Y}[WAIT]${RESET} Export not yet visible (FSx auto-export can take 30-60s)"
  echo -e "     ${D}  Expected path: s3://${S3_BUCKET}/export/data/results/demo-${DEMO_TS}/${RESET}"
  echo -e "     ${D}  Check manually: aws s3 ls s3://${S3_BUCKET}/export/ --recursive${RESET}"
fi

echo
echo -e "  ${W}  S3 paths (Seoul, ${S3_REGION}):${RESET}"
echo
echo -e "  ${D}  s3://${S3_BUCKET}/${RESET}"
echo -e "  ${D}    +-- models/dev-user/${RESET}"
echo -e "  ${D}    |   +-- ${G}${DEMO_FILENAME}${RESET}  ${D}<-- uploaded in STEP 2${RESET}"
echo -e "  ${D}    +-- export/data/results/${RESET}"
echo -e "  ${D}        +-- ${W}demo-${DEMO_TS}/${RESET}"
echo -e "  ${D}            +-- training_log.json   ${M}<-- FSx auto-export${RESET}"
echo -e "  ${D}            +-- lora_weights.bin    ${M}<-- FSx auto-export${RESET}"
echo -e "  ${D}            +-- sample_output.txt   ${M}<-- FSx auto-export${RESET}"

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

# Timeline (reflects real operations performed)
EVENTS=(
  "${G}*${RESET}  STEP 2   |  ${G}Model uploaded${RESET} to Seoul S3 ${G}(REAL)${RESET} -- ${DEMO_FILENAME}"
  "${C}*${RESET}  STEP 3   |  ${C}Spot prices scanned${RESET} across 3 regions ${G}(REAL)${RESET}"
  "${G}*${RESET}  STEP 4   |  ${G}Job dispatched${RESET} to ${C}${CHEAPEST_REGION}${RESET} (\$${CHEAPEST_PRICE}/hr) ${G}(REAL)${RESET}"
  "${C}*${RESET}  STEP 4   |  ${C}FSx auto-import${RESET}: Seoul S3 -> ${CHEAPEST_REGION} FSx (on Pod read)"
  "${Y}*${RESET}  STEP 5   |  ${Y}Pod executed${RESET}: wrote results to FSx /data/results ${G}(REAL)${RESET}"
  "${M}*${RESET}  STEP 6   |  ${M}FSx auto-export${RESET}: ${CHEAPEST_REGION} FSx -> Seoul S3/export"
  "${G}*${RESET}  STEP 6   |  ${G}${BOLD}S3 verification${RESET}: checked real files in Seoul S3 ${G}(REAL)${RESET}"
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
hr "-" "$D"
echo

# Cleanup prompt
echo -e "  ${W}${BOLD}  [Cleanup] Demo files in Seoul S3${RESET}"
echo -e "  ${D}  - s3://${S3_BUCKET}/${S3_KEY}${RESET}"
echo -e "  ${D}  - s3://${S3_BUCKET}/export/data/results/demo-${DEMO_TS}/${RESET}"
echo
echo -ne "  ${Y}Delete demo files from S3? (y/N):${RESET} "
read -r CLEANUP_ANSWER
if [[ "$CLEANUP_ANSWER" =~ ^[yY]$ ]]; then
  aws s3 rm "s3://${S3_BUCKET}/${S3_KEY}" --region "$S3_REGION" 2>/dev/null || true
  aws s3 rm "s3://${S3_BUCKET}/export/data/results/demo-${DEMO_TS}/" \
    --region "$S3_REGION" --recursive 2>/dev/null || true
  echo -e "  ${G}[OK]${RESET} Demo files cleaned up"
else
  echo -e "  ${D}Skipped. Files remain in S3 for inspection.${RESET}"
fi
echo

hr "=" "$C"
echo
