#!/usr/bin/env bash

set -o pipefail

# -------------------- CLI --------------------
usage() {
  cat <<'EOF'
Usage:
  ./inventory.sh         
  ./inventory.sh --save     # Inventory_HOST_TIMESTAMP/inventory.txt
  ./inventory.sh -h|--help  

Notes:
- For better PID/process evidence on listening ports, run with sudo:
    sudo ./inventory.sh --save
EOF
}

SAVE=0
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
elif [[ "${1:-}" == "--save" ]]; then
  SAVE=1
elif [[ -n "${1:-}" ]]; then
  echo "Unknown option: $1" >&2
  usage >&2
  exit 2
fi

# -------------------- Helpers --------------------
have() { command -v "$1" >/dev/null 2>&1; }

HOST="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown)"
TS="$(date +%F_%H%M%S 2>/dev/null || echo unknown_time)"

OUTDIR="Inventory_${HOST}_${TS}"
OUTFILE="${OUTDIR}/inventory.txt"

if [[ "$SAVE" -eq 1 ]]; then
  mkdir -p "$OUTDIR" 2>/dev/null || true
  : > "$OUTFILE" 2>/dev/null || true
fi

add() {
  # Print to screen always
  printf "%s\n" "$*"
  if [[ "$SAVE" -eq 1 ]]; then
    printf "%s\n" "$*" >> "$OUTFILE" 2>/dev/null || true
  fi
}

section() { add ""; add "==== $* ===="; }

tmpdir="$(mktemp -d 2>/dev/null || echo "")"
cleanup() { [[ -n "$tmpdir" && -d "$tmpdir" ]] && rm -rf "$tmpdir" 2>/dev/null || true; }
trap cleanup EXIT

# -------------------- OS Info --------------------
OS_PRETTY="(Unable to read OS info)"
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release 2>/dev/null || true
  OS_PRETTY="${PRETTY_NAME:-${NAME:-unknown}}"
fi
KERNEL="$(uname -r 2>/dev/null || echo unknown)"

# -------------------- IPs (IPv4) --------------------
get_ips() {
  if have ip; then
    # interface + IPv4 (no loopback)
    ip -br -4 addr show 2>/dev/null | awk '$1!="lo" {print $1": "$3}' | sed 's#/.*##'
  elif have ifconfig; then
    # fallback
    ifconfig 2>/dev/null | awk '
      $1 ~ /flags=/ {iface=$1; gsub(":", "", iface)}
      $1=="inet" && $2!="127.0.0.1" {print iface": "$2}
    '
  else
    return 1
  fi
}

# -------------------- Listening ports evidence --------------------
get_listeners_raw() {
  if have ss; then
    ss -lntup 2>/dev/null || true
  elif have netstat; then
    netstat -lntup 2>/dev/null || true
  else
    return 1
  fi
}

parse_ss() {
  # Input: ss -lntup (raw)
  awk '
    {
      proto=$1
      local=$4
      # port is after last colon (handles [::]:443 too)
      sub(/.*:/,"",local)
      port=local

      pid=""; proc=""
      # find pid=123
      if (match($0, /pid=[0-9]+/)) {
        pid=substr($0, RSTART+4, RLENGTH-4)
      }
      # find first process name inside users:(("PROC",
      if (match($0, /users:\(\("[^"]+"/)) {
        s=substr($0, RSTART, RLENGTH)
        sub(/users:\(\("/, "", s)
        proc=s
      }

      if (port ~ /^[0-9]+$/) {
        print proto, port, pid, proc
      }
    }
  '
}

# Parse netstat output -> "proto port pid proc" (best effort)
parse_netstat() {
  # netstat -lntup: Proto Recv-Q Send-Q Local Address Foreign Address State PID/Program name
  awk '
    NR>2 {
      proto=$1
      local=$4
      sub(/.*:/,"",local)
      port=local

      pid=""; proc=""
      pidproc=$7
      if (pidproc ~ /[0-9]+\//) {
        split(pidproc,a,"/")
        pid=a[1]
        proc=a[2]
      }

      if (port ~ /^[0-9]+$/) {
        print proto, port, pid, proc
      }
    }
  '
}

norm_proto() {
  case "${1:-}" in
    tcp|tcp6) echo "tcp" ;;
    udp|udp6) echo "udp" ;;
    *) echo "${1:-?}" ;;
  esac
}

service_label() {
  case "${1:-}" in
    22)   echo "Remote (ssh)" ;;
    80)   echo "HTTP" ;;
    443)  echo "HTTPS" ;;
    3389) echo "Remote (rdp)" ;;
    445)  echo "File Share (smb)" ;;
    135)  echo "RPC" ;;
    53)   echo "DNS" ;;
    389)  echo "Domain Controller (ldap)" ;;
    636)  echo "Domain Controller (ldaps)" ;;
    88)   echo "Domain Controller (kerberos)" ;;
    1433) echo "Database (mssql)" ;;
    3306) echo "Database (mysql)" ;;
    5432) echo "Database (postgres)" ;;
    25)   echo "Mail (smtp)" ;;
    110)  echo "Mail (pop3)" ;;
    143)  echo "Mail (imap)" ;;
    587)  echo "Mail (submission)" ;;
    *)    echo "" ;;
  esac
}

# -------------------- Report --------------------
add "Inventory Report"
add "Generated: $(date 2>/dev/null || echo unknown_date)"
add ""
add "Host:"
add "  $HOST"
add ""
add "Operating System:"
add "  $OS_PRETTY (Kernel $KERNEL)"
add ""

if [[ "$(id -u 2>/dev/null || echo 9999)" != "0" ]]; then
  add "Note:"
  add "  Not running as root. Listening PID/process evidence may be limited."
  add "  Tip: sudo ./inventory.sh ${SAVE:+--save}"
  add ""
fi

section "IP Addresses (IPv4)"
IPS="$(get_ips 2>/dev/null || true)"
if [[ -n "${IPS//[[:space:]]/}" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && add "  $line"
  done <<< "$IPS"
else
  if have ip || have ifconfig; then
    add "  (none found)"
  else
    add "  (missing command: ip / ifconfig)"
  fi
fi

section "Listening Ports (RAW evidence)"
RAW="$(get_listeners_raw || true)"
if [[ -n "${RAW//[[:space:]]/}" ]]; then
  if have ss; then
    add "  Source: ss -lntup"
  else
    add "  Source: netstat -lntup"
  fi
  add ""
  # indent raw lines
  while IFS= read -r line; do
    add "  $line"
  done <<< "$RAW"
else
  if have ss || have netstat; then
    add "  (no output or insufficient permissions)"
  else
    add "  (missing command: ss / netstat)"
  fi
fi

# Best-effort parse into rows
ROWS=""
if [[ -n "${RAW//[[:space:]]/}" ]]; then
  if have ss; then
    ROWS="$(printf "%s\n" "$RAW" | parse_ss 2>/dev/null || true)"
  else
    ROWS="$(printf "%s\n" "$RAW" | parse_netstat 2>/dev/null || true)"
  fi
fi

# Use temp files to avoid bash associative arrays (more compatible)
mapped_file="${tmpdir}/mapped.txt"
unmapped_file="${tmpdir}/unmapped.txt"
services_file="${tmpdir}/services.txt"
evidence_file="${tmpdir}/evidence.txt"
: > "$mapped_file" 2>/dev/null || true
: > "$unmapped_file" 2>/dev/null || true
: > "$services_file" 2>/dev/null || true
: > "$evidence_file" 2>/dev/null || true

if [[ -n "${ROWS//[[:space:]]/}" ]]; then
  while IFS= read -r proto port pid proc; do
    [[ -z "${port:-}" ]] && continue
    p="$(norm_proto "$proto")"
    label="$(service_label "$port")"

    # evidence line
    [[ -z "${pid:-}" ]] && pid="?"
    [[ -z "${proc:-}" ]] && proc="?"
    if [[ -n "$label" ]]; then
      printf "%s\n" "${port}/${p}  PID:${pid}  Proc:${proc}  | Mapped:${label}" >> "$evidence_file" 2>/dev/null || true
      printf "%s\n" "$label" >> "$services_file" 2>/dev/null || true
      printf "%s\n" "${port}/${p} -> ${label}" >> "$mapped_file" 2>/dev/null || true
    else
      printf "%s\n" "${port}/${p}" >> "$unmapped_file" 2>/dev/null || true
      printf "%s\n" "${port}/${p}  PID:${pid}  Proc:${proc}" >> "$evidence_file" 2>/dev/null || true
    fi
  done <<< "$ROWS"
fi

section "Services (inferred from listening ports)"
if [[ -s "$services_file" ]]; then
  svc_line="$(sort -u "$services_file" 2>/dev/null | paste -sd ", " - 2>/dev/null || true)"
  [[ -n "${svc_line//[[:space:]]/}" ]] && add "  $svc_line" || add "  (none mapped)"
else
  add "  (none mapped - only unmapped/ephemeral ports detected, or parsing failed)"
fi

section "Required Ports (mapped)"
if [[ -s "$mapped_file" ]]; then
  sort -u "$mapped_file" 2>/dev/null | sort -t/ -k1,1n -k2,2 2>/dev/null | while IFS= read -r line; do
    add "  $line"
  done
else
  add "  (none)"
fi

section "Other Listening Ports (unmapped)"
if [[ -s "$unmapped_file" ]]; then
  sort -u "$unmapped_file" 2>/dev/null | sort -t/ -k1,1n -k2,2 2>/dev/null | while IFS= read -r line; do
    add "  $line"
  done
else
  add "  (none)"
fi

section "Evidence (Listening Port -> Process -> Service/Program)"
if [[ -s "$evidence_file" ]]; then
  sort -u "$evidence_file" 2>/dev/null | sort -t/ -k1,1n -k2,2 2>/dev/null | while IFS= read -r line; do
    add "  $line"
  done
else
  add "  (no parsed evidence; see RAW evidence above)"
fi

section "Containers"
if have docker; then
  add "  Docker detected:"
  docker ps -a --format '  {{.Names}} | {{.Image}} | {{.Status}} | {{.Ports}}' 2>/dev/null \
    || add "  (docker command failed or insufficient permissions)"
else
  add "  Docker not installed."
fi

if [[ "$SAVE" -eq 1 ]]; then
  add ""
  add "Saved to: $(pwd)/${OUTFILE}"
  echo "Saved: ${OUTFILE}" >&2
fi
