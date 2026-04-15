#!/usr/bin/env bash
# ============================================================
#  GPU Spot Lotto -- Demo Launcher
#  모든 데모 시나리오를 하나의 메뉴에서 선택하고 실행합니다.
# ============================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ─────────────────────────────────────────────────
R='\033[0;31m';  G='\033[0;32m';  Y='\033[0;33m';  B='\033[0;34m'
M='\033[0;35m';  C='\033[0;36m';  W='\033[1;37m';  D='\033[0;90m'
BG_B='\033[44m'; BG_G='\033[42m'; BG_R='\033[41m'; BG_Y='\033[43m'
BG_M='\033[45m'; BG_C='\033[46m'; BG_D='\033[100m'
RESET='\033[0m'; BOLD='\033[1m'

COLS=$(tput cols 2>/dev/null || echo 80)

hr() {
  local ch="${1:--}" color="${2:-$D}"
  printf '%b' "$color"
  for ((i=0; i<COLS; i++)); do printf '%s' "$ch"; done
  printf '%b\n' "$RESET"
}

center() {
  local text="$1"
  local pad
  pad=$(( (COLS - ${#text}) / 2 ))
  [ "$pad" -lt 0 ] && pad=0
  printf '%*s%s\n' "$pad" '' "$text"
}

# ── System status ──────────────────────────────────────────
fetch_status() {
  local api="${GPU_LOTTO_URL:-https://d370iz4ydsallw.cloudfront.net}"

  # health
  local health
  health=$(curl -s --connect-timeout 3 "$api/healthz" 2>/dev/null)
  if echo "$health" | grep -q '"ok"\|"healthy"' 2>/dev/null; then
    HEALTH_STATUS="${G}HEALTHY${RESET}"
  else
    HEALTH_STATUS="${R}DOWN${RESET}"
  fi

  # prices
  local price_data
  price_data=$(curl -s --connect-timeout 3 "$api/api/prices" 2>/dev/null)
  if [ -n "$price_data" ]; then
    PRICE_SUMMARY=$(echo "$price_data" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    prices = d.get('prices', d) if isinstance(d, dict) else d
    if not prices:
        print('No data')
    else:
        cheapest = min(prices, key=lambda p: p['price'])
        print(f\"{len(prices)} prices | Best: \${cheapest['price']:.4f} {cheapest['instance_type']} ({cheapest['region']})\")
except:
    print('N/A')
" 2>/dev/null)
  else
    PRICE_SUMMARY="N/A"
  fi

  # queue
  local stats
  stats=$(curl -s --connect-timeout 3 "$api/api/admin/stats" 2>/dev/null)
  if [ -n "$stats" ]; then
    QUEUE_SUMMARY=$(echo "$stats" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    total = d.get('total_jobs', d.get('total', 0))
    queue = d.get('queue_depth', d.get('queued', 0))
    print(f'Jobs: {total} | Queue: {queue}')
except:
    print('N/A')
" 2>/dev/null)
  else
    QUEUE_SUMMARY="N/A"
  fi
}

# ── Draw menu ──────────────────────────────────────────────
draw_menu() {
  clear

  # logo
  echo
  printf '%b' "$B$BOLD"
  cat << 'LOGO'
      ██████╗ ██████╗ ██╗   ██╗    ███████╗██████╗  ██████╗ ████████╗
     ██╔════╝ ██╔══██╗██║   ██║    ██╔════╝██╔══██╗██╔═══██╗╚══██╔══╝
     ██║  ███╗██████╔╝██║   ██║    ███████╗██████╔╝██║   ██║   ██║
     ██║   ██║██╔═══╝ ██║   ██║    ╚════██║██╔═══╝ ██║   ██║   ██║
     ╚██████╔╝██║     ╚██████╔╝    ███████║██║     ╚██████╔╝   ██║
      ╚═════╝ ╚═╝      ╚═════╝     ╚══════╝╚═╝      ╚═════╝    ╚═╝
LOGO
  printf '%b' "$RESET"
  printf '%b' "$W$BOLD"
  center "L O T T O"
  printf '%b\n' "$RESET"

  # status bar
  printf '%b' "$BG_D$W$BOLD"
  printf '%*s' "$COLS" '' | tr ' ' ' '
  printf '%b\n' "$RESET"
  printf '%b' "$BG_D$W"
  local status_line
  status_line="  API: $(printf '%b' "$HEALTH_STATUS$BG_D$W")  |  $PRICE_SUMMARY  |  $QUEUE_SUMMARY  "
  printf "  API: %b  |  %s  |  %s%*s" "$HEALTH_STATUS$BG_D$W" "$PRICE_SUMMARY" "$QUEUE_SUMMARY" 10 ""
  printf '%b\n' "$RESET"
  printf '%b' "$BG_D$W$BOLD"
  printf '%*s' "$COLS" '' | tr ' ' ' '
  printf '%b\n' "$RESET"
  echo

  # scenarios
  hr '=' "$W$BOLD"
  printf '%b' "$W$BOLD"
  center "DEMO SCENARIOS"
  printf '%b' "$RESET"
  hr '=' "$W$BOLD"
  echo

  # menu items
  printf '  %b%b [1] %b  %b%-52s%b %b%s%b\n' \
    "$BOLD" "$BG_B$W" "$RESET" "$BOLD$W" "Cost-Optimized Dispatch" "$RESET" \
    "$D" "최저가 리전 자동 배치" "$RESET"
  printf '      %bSpot 가격 스캔 -> 최저가 분석 -> 자동 배치 -> 비용 절감 리포트%b\n' "$D" "$RESET"
  echo

  printf '  %b%b [2] %b  %b%-52s%b %b%s%b\n' \
    "$BOLD" "$BG_G$W" "$RESET" "$BOLD$W" "Spot Interruption Recovery" "$RESET" \
    "$D" "스팟 회수 자동 복구" "$RESET"
  printf '      %b체크포인트 학습 -> Spot 회수 시뮬 -> 자동 재배치 -> 학습 재개%b\n' "$D" "$RESET"
  echo

  printf '  %b%b [3] %b  %b%-52s%b %b%s%b\n' \
    "$BOLD" "$BG_Y$W" "$RESET" "$BOLD$W" "Full GPU Lifecycle" "$RESET" \
    "$D" "전체 라이프사이클" "$RESET"
  printf '      %bS3 업로드 -> FSx 동기화 -> GPU 학습 -> 결과 Export -> 비용 분석%b\n' "$D" "$RESET"
  echo

  printf '  %b%b [4] %b  %b%-52s%b %b%s%b\n' \
    "$BOLD" "$BG_M$W" "$RESET" "$BOLD$W" "AI Agent Smart Dispatch" "$RESET" \
    "$D" "AI 에이전트 스마트 배치" "$RESET"
  printf '      %bAgentCore + Strands -> 자연어 분석 -> 장애 이력 -> 지능형 배치%b\n' "$D" "$RESET"
  echo

  hr '-' "$D"
  echo

  printf '  %b%b [5] %b  %b%-52s%b %b%s%b\n' \
    "$BOLD" "$BG_C$W" "$RESET" "$BOLD$C" "Multi-Region Pod Monitor" "$RESET" \
    "$D" "리전별 GPU Pod 실시간 감시" "$RESET"
  printf '      %b3개 Spot 리전 Pod 상태 + Spot 가격 실시간 모니터 (별도 터미널 권장)%b\n' "$D" "$RESET"
  echo

  hr '=' "$W$BOLD"
  echo
  printf '  %b [q] %b  Quit\n' "$BG_R$W$BOLD" "$RESET"
  echo
  hr '=' "$W$BOLD"
  echo
}

# ── Run a scenario ─────────────────────────────────────────
run_scenario() {
  local script="$1" label="$2"
  echo
  hr '=' "$Y"
  printf '  %b>>> Running: %s%b\n' "$Y$BOLD" "$label" "$RESET"
  hr '=' "$Y"
  echo

  bash "$SCRIPT_DIR/$script"
  local rc=$?

  echo
  if [ $rc -eq 0 ]; then
    printf '  %b[DONE]%b %s completed successfully.\n' "$G$BOLD" "$RESET" "$label"
  else
    printf '  %b[EXIT]%b %s exited with code %d.\n' "$Y$BOLD" "$RESET" "$label" "$rc"
  fi
  echo
  echo -ne "  ${D}Press Enter to return to menu...${RESET}"
  read -r
}

# ── Main loop ──────────────────────────────────────────────
trap 'printf "\n%b\nGoodbye!%b\n" "$D" "$RESET"; exit 0' INT

while true; do
  fetch_status
  draw_menu

  printf '  %b%b  Select [1-5, q]: %b ' "$BOLD" "$W" "$RESET"
  read -r choice

  case "$choice" in
    1) run_scenario "scenario1-cost-optimized.sh" "Scenario 1: Cost-Optimized Dispatch" ;;
    2) run_scenario "scenario2-spot-recovery.sh"  "Scenario 2: Spot Interruption Recovery" ;;
    3) run_scenario "scenario3-full-lifecycle.sh"  "Scenario 3: Full GPU Lifecycle" ;;
    4) run_scenario "scenario4-ai-agent.sh"        "Scenario 4: AI Agent Smart Dispatch" ;;
    5)
      echo
      printf '  %bStarting Pod Monitor (Ctrl+C to stop, then returns here)...%b\n' "$C" "$RESET"
      echo
      bash "$SCRIPT_DIR/watch-gpu-pods.sh" 5
      ;;
    q|Q|quit|exit)
      echo
      printf '  %bGoodbye!%b\n\n' "$D" "$RESET"
      exit 0
      ;;
    *)
      printf '\n  %b!! Invalid selection: %s%b\n' "$R" "$choice" "$RESET"
      sleep 1
      ;;
  esac
done
