#!/usr/bin/env bash
# ============================================================
#  GPU Spot Lotto -- Multi-Region Pod Monitor
#  실시간으로 3개 Spot 리전의 GPU 작업 Pod를 모니터링합니다.
# ============================================================
set -uo pipefail

INTERVAL="${1:-5}"
NAMESPACE="${GPU_JOBS_NS:-gpu-jobs}"
CLUSTER_PREFIX="${CLUSTER_PREFIX:-gpu-lotto-dev}"

# ── Colors ─────────────────────────────────────────────────
R='\033[0;31m';  G='\033[0;32m';  Y='\033[0;33m';  B='\033[0;34m'
C='\033[0;36m';  W='\033[1;37m';  D='\033[0;90m'
BG_B='\033[44m'; BG_G='\033[42m'; BG_R='\033[41m'; BG_Y='\033[43m'
BG_C='\033[46m'
RESET='\033[0m'; BOLD='\033[1m'

REGIONS=("us-east-1:use1" "us-east-2:use2" "us-west-2:usw2")

REGION_COLORS=("$BG_B" "$BG_G" "$BG_C")

hr() {
  local ch="${1:--}" n="${2:-80}"
  local line=""
  for ((i=0; i<n; i++)); do line+="$ch"; done
  echo "$line"
}

center() {
  local text="$1" width="${2:-80}"
  local pad
  pad=$(( (width - ${#text}) / 2 ))
  [ "$pad" -lt 0 ] && pad=0
  printf '%*s%s' "$pad" '' "$text"
}

status_color() {
  case "$1" in
    Running)   printf '%b%s%b' "$G" "$1" "$RESET" ;;
    Succeeded) printf '%b%s%b' "$C" "$1" "$RESET" ;;
    Pending)   printf '%b%s%b' "$Y" "$1" "$RESET" ;;
    Failed)    printf '%b%s%b' "$R" "$1" "$RESET" ;;
    Unknown)   printf '%b%s%b' "$R" "$1" "$RESET" ;;
    *)         printf '%s' "$1" ;;
  esac
}

render() {
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  local now
  now=$(date '+%Y-%m-%d %H:%M:%S')
  local total_pods=0

  # header
  clear
  printf '%b' "$BOLD$W"
  hr '=' "$cols"
  center "GPU SPOT LOTTO -- MULTI-REGION POD MONITOR" "$cols"
  echo
  printf '%b' "$RESET$D"
  center "namespace: $NAMESPACE | refresh: ${INTERVAL}s | $now" "$cols"
  echo
  printf '%b' "$BOLD$W"
  hr '=' "$cols"
  printf '%b\n' "$RESET"

  local idx=0
  for entry in "${REGIONS[@]}"; do
    local region="${entry%%:*}"
    local short="${entry##*:}"
    local ctx="${CLUSTER_PREFIX}-${short}"
    local color="${REGION_COLORS[$idx]}"

    # region header
    printf '%b %b %-14s %b  context: %s\n' \
      "$BOLD" "$color" " $region " "$RESET$D" "$ctx"
    printf '%b' "$RESET"
    hr '-' "$cols"

    # fetch pods
    local output
    output=$(kubectl get pods -n "$NAMESPACE" --context "$ctx" \
      -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,IP:.status.podIP,AGE:.metadata.creationTimestamp,GPU:.spec.containers[0].resources.limits.nvidia\.com/gpu' \
      --no-headers 2>&1)

    if [ -z "$output" ] || echo "$output" | grep -q "No resources found"; then
      printf '  %b(no pods)%b\n' "$D" "$RESET"
    elif echo "$output" | grep -q "error\|Unable\|refused"; then
      printf '  %b!! %s%b\n' "$R" "$output" "$RESET"
    else
      # column header
      printf '  %b%-46s %-12s %-20s %-16s %s%b\n' \
        "$D" "POD" "STATUS" "NODE" "IP" "GPU" "$RESET"

      while IFS= read -r line; do
        local name status node ip age gpu
        name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')
        node=$(echo "$line" | awk '{print $3}')
        ip=$(echo "$line" | awk '{print $4}')
        gpu=$(echo "$line" | awk '{print $6}')
        [ "$node" = "<none>" ] && node="-"
        [ "$ip" = "<none>" ] && ip="-"
        [ "$gpu" = "<none>" ] && gpu="-"

        printf '  %-46s ' "$name"
        status_color "$status"
        printf '%-5s %-20s %-16s %s\n' "" "$node" "$ip" "$gpu"
        total_pods=$((total_pods + 1))
      done <<< "$output"
    fi
    echo
    idx=$((idx + 1))
  done

  # summary bar
  printf '%b' "$BOLD$W"
  hr '=' "$cols"
  printf '%b' "$RESET"

  # live prices summary
  local price_data
  price_data=$(curl -s --connect-timeout 3 "${GPU_LOTTO_URL:-https://d370iz4ydsallw.cloudfront.net}/api/prices" 2>/dev/null)

  if [ -n "$price_data" ] && echo "$price_data" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    local summary
    summary=$(echo "$price_data" | python3 -c "
import sys, json
d = json.load(sys.stdin)
prices = d.get('prices', d) if isinstance(d, dict) else d
by_region = {}
for p in prices:
    r = p['region']
    if r not in by_region or p['price'] < by_region[r]['price']:
        by_region[r] = p
parts = []
for r in sorted(by_region):
    p = by_region[r]
    parts.append(f\"{r}: \${p['price']:.4f} ({p['instance_type']})\")
print(' | '.join(parts))
" 2>/dev/null)
    printf '  %bBest prices%b  %s\n' "$Y" "$RESET" "$summary"
  fi

  printf '  %bTotal pods:%b %d across 3 regions    %bCtrl+C%b to exit\n' \
    "$C" "$RESET" "$total_pods" "$D" "$RESET"
  printf '%b' "$BOLD$W"
  hr '=' "$cols"
  printf '%b\n' "$RESET"
}

# ── Main loop ──────────────────────────────────────────────
trap 'printf "\n%bMonitor stopped.%b\n" "$D" "$RESET"; exit 0' INT TERM

echo -e "${BOLD}Starting GPU Pod Monitor (refresh: ${INTERVAL}s)...${RESET}"

while true; do
  render
  sleep "$INTERVAL"
done
