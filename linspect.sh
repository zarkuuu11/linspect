#!/usr/bin/env bash
#
# linspect — Linux system inspection & health-check tool
# https://github.com/<your-username>/linspect
#
# Usage: ./linspect.sh [OPTIONS]
#
# A single self-contained bash script for quickly inspecting the health
# and security posture of a Linux machine: CPU, memory, disk, network,
# processes, and basic security checks — with colored terminal output
# and optional JSON / text report export.

set -uo pipefail

VERSION="1.0.0"

# ---------- colors ----------
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
  C_RED='\033[31m'; C_GREEN='\033[32m'; C_YELLOW='\033[33m'
  C_BLUE='\033[34m'; C_CYAN='\033[36m'; C_MAGENTA='\033[35m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_MAGENTA=''
fi

# ---------- state ----------
MODE="full"        # full | quick | security | json
EXPORT_PATH=""
JSON_MODE=false

# ---------- helpers ----------
header() { printf "\n${C_BOLD}${C_CYAN}▸ %s${C_RESET}\n" "$1"; }
kv()     { printf "  ${C_DIM}%-22s${C_RESET} %s\n" "$1" "$2"; }
ok()     { printf "  ${C_GREEN}✔${C_RESET} %s\n" "$1"; }
warn()   { printf "  ${C_YELLOW}⚠${C_RESET} %s\n" "$1"; }
bad()    { printf "  ${C_RED}✘${C_RESET} %s\n" "$1"; }
has()    { command -v "$1" &>/dev/null; }

print_banner() {
  printf "${C_MAGENTA}${C_BOLD}"
  cat <<'EOF'
  _ _                           _
 | (_)_ __  ___ _ __   ___  ___| |_
 | | | '_ \/ __| '_ \ / _ \/ __| __|
 | | | | | \__ \ |_) |  __/ (__| |_
 |_|_|_| |_|___/ .__/ \___|\___|\__|
               |_|
EOF
  printf "${C_RESET}${C_DIM}  linux system inspector · v${VERSION}${C_RESET}\n"
}

usage() {
  print_banner
  cat <<EOF

${C_BOLD}Usage:${C_RESET} $(basename "$0") [OPTIONS]

${C_BOLD}Options:${C_RESET}
  -q, --quick        quick summary only (CPU, RAM, disk, uptime)
  -s, --security      run security checks only
  -j, --json          output as JSON instead of formatted text
  -o, --output FILE   write report to FILE (text or .json by extension)
  -h, --help          show this help
  -v, --version       show version

${C_BOLD}Examples:${C_RESET}
  ./linspect.sh                 full report, printed to terminal
  ./linspect.sh -q              quick health summary
  ./linspect.sh -s              security-focused checks
  ./linspect.sh -j -o out.json  full report exported as JSON
EOF
}

# ---------- argument parsing ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--quick) MODE="quick"; shift ;;
    -s|--security) MODE="security"; shift ;;
    -j|--json) JSON_MODE=true; shift ;;
    -o|--output) EXPORT_PATH="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -v|--version) echo "linspect v${VERSION}"; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ---------- data collectors ----------
get_os()       { [[ -f /etc/os-release ]] && (. /etc/os-release; echo "$PRETTY_NAME") || uname -s; }
get_kernel()   { uname -r; }
get_uptime()   { uptime -p 2>/dev/null || uptime; }
get_hostname() { hostname; }

get_cpu_load() {
  if has mpstat; then
    mpstat 1 1 | awk '/Average/ {printf "%.1f%%", 100-$NF}'
  else
    awk '{printf "%.2f, %.2f, %.2f (1/5/15 min)", $1, $2, $3}' /proc/loadavg
  fi
}

get_cpu_count() { nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo; }

get_mem() {
  free -h | awk '/^Mem:/ {print $3 " / " $2 " used (" $7 " available)"}'
}

get_mem_percent() {
  free | awk '/^Mem:/ {printf "%.0f", $3/$2*100}'
}

get_disk() {
  df -h --output=target,size,used,avail,pcent 2>/dev/null | grep -E '^/($|home|var)' \
    || df -h / 2>/dev/null | tail -1 | awk '{print $6" "$2" total, "$3" used, "$4" avail ("$5")"}'
}

get_disk_percent() {
  df / 2>/dev/null | tail -1 | awk '{gsub("%","",$5); print $5}'
}

get_top_procs() {
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | head -6 | tail -5
}

get_users() { who | wc -l; }

get_listening_ports() {
  if has ss; then
    ss -tuln 2>/dev/null | awk 'NR>1 {print $1, $5}' | sort -u
  elif has netstat; then
    netstat -tuln 2>/dev/null | awk 'NR>2 {print $1, $4}' | sort -u
  fi
}

get_failed_logins() {
  if has journalctl; then
    journalctl -u ssh -u sshd --since "-7 days" 2>/dev/null | grep -ci "failed password" || echo 0
  elif [[ -f /var/log/auth.log ]]; then
    grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo 0
  else
    echo "n/a"
  fi
}

get_updates_pending() {
  if has apt; then
    apt list --upgradable 2>/dev/null | grep -c upgradable
  elif has dnf; then
    dnf check-update 2>/dev/null | grep -c '^[a-zA-Z]'
  elif has pacman; then
    pacman -Qu 2>/dev/null | wc -l
  else
    echo "n/a"
  fi
}

# ---------- report sections ----------
section_overview() {
  header "სისტემის მიმოხილვა"
  kv "Hostname" "$(get_hostname)"
  kv "OS" "$(get_os)"
  kv "Kernel" "$(get_kernel)"
  kv "Uptime" "$(get_uptime)"
  kv "Active users" "$(get_users)"
}

section_resources() {
  header "რესურსები"
  kv "CPU cores" "$(get_cpu_count)"
  kv "CPU load" "$(get_cpu_load)"
  kv "Memory" "$(get_mem)"
  kv "Disk (/)" "$(get_disk | head -1)"

  local mem_pct disk_pct
  mem_pct=$(get_mem_percent)
  disk_pct=$(get_disk_percent)
  echo
  [[ "$mem_pct" -lt 80 ]] && ok "მეხსიერების გამოყენება ნორმაშია (${mem_pct}%)" \
    || warn "მეხსიერების გამოყენება მაღალია (${mem_pct}%)"
  [[ "$disk_pct" -lt 85 ]] && ok "დისკის სივრცე საკმარისია (${disk_pct}%)" \
    || warn "დისკი თითქმის სავსეა (${disk_pct}%)"
}

section_processes() {
  header "ყველაზე დატვირთული პროცესები"
  printf "  ${C_DIM}%-8s %-20s %-8s %-8s${C_RESET}\n" "PID" "COMMAND" "%CPU" "%MEM"
  get_top_procs | awk '{printf "  %-8s %-20s %-8s %-8s\n", $1, $2, $3, $4}'
}

section_security() {
  header "უსაფრთხოების სწრაფი შემოწმება"
  local failed updates
  failed=$(get_failed_logins)
  updates=$(get_updates_pending)

  if [[ "$failed" == "n/a" ]]; then
    warn "წარუმატებელი login-ების ლოგი ვერ მოიძებნა"
  elif [[ "$failed" -eq 0 ]]; then
    ok "წარუმატებელი SSH login-ები ბოლო 7 დღეში: 0"
  else
    bad "წარუმატებელი SSH login-ები ბოლო 7 დღეში: $failed"
  fi

  if [[ "$updates" == "n/a" ]]; then
    warn "პაკეტების მენეჯერი ვერ მოიძებნა"
  elif [[ "$updates" -eq 0 ]]; then
    ok "სისტემა განახლებულია"
  else
    warn "მოსალოდნელი განახლებები: $updates"
  fi

  echo
  kv "მოსმენადი პორტები" ""
  get_listening_ports | sed 's/^/    /'
}

# ---------- JSON output ----------
print_json() {
  local mem_pct disk_pct failed updates
  mem_pct=$(get_mem_percent); disk_pct=$(get_disk_percent)
  failed=$(get_failed_logins); updates=$(get_updates_pending)
  cat <<EOF
{
  "hostname": "$(get_hostname)",
  "os": "$(get_os)",
  "kernel": "$(get_kernel)",
  "uptime": "$(get_uptime)",
  "cpu_cores": $(get_cpu_count),
  "memory_percent_used": ${mem_pct:-0},
  "disk_percent_used": ${disk_pct:-0},
  "active_users": $(get_users),
  "failed_ssh_logins_7d": "${failed}",
  "pending_updates": "${updates}"
}
EOF
}

# ---------- main ----------
run_report() {
  if $JSON_MODE; then
    print_json
    return
  fi

  print_banner
  case "$MODE" in
    quick)
      section_overview
      section_resources
      ;;
    security)
      section_security
      ;;
    full)
      section_overview
      section_resources
      section_processes
      section_security
      ;;
  esac
  echo
}

if [[ -n "$EXPORT_PATH" ]]; then
  run_report > "$EXPORT_PATH"
  echo "რეპორტი შენახულია: $EXPORT_PATH"
else
  run_report
fi
