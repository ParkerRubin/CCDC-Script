#!/usr/bin/env bash
# ============================================================
# CYBERFORCE 2026 — FIREWALL BASELINE — TASK (OpenSUSE Leap)
# Required scored inbound (per official AWS doc):
#   HTTP    80/tcp
#   MySQL   3306/tcp
#   SMB     139/tcp 445/tcp   (UDP 137-138 NOT scored — see note)
#   SSH     22/tcp            (team access)
# Rules of play: NO allow-lists, NO subnet/CIDR blocks.
# Default: block all inbound, allow outbound. Open ONLY the
# ports above (plus anything you add at the prompt).
# Log every change you make → Security Documentation (Nov 9).
# ============================================================
set -u

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo (sudo bash firewall.sh)" >&2
  exit 1
fi

REQ_TCP="22 80 3306 139 445"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$HOME/cf-firewall-backup-$TS.txt"

echo "=== CYBERFORCE FIREWALL — TASK (OpenSUSE Leap) ==="
echo "Required ports: $REQ_TCP"
echo

# ---- capture the pre-change state (rollback reference) ----
( ufw status verbose 2>/dev/null || true
  firewall-cmd --list-all-zones 2>/dev/null || true ) > "$BACKUP"
echo "Backup of current config: $BACKUP"

# ---- optional extra ports at the prompt ----
read -rp "Extra inbound TCP ports to ALLOW, comma-separated (blank=none): " extra
EXTRA_TCP=$(echo "$extra" | tr -d ' ' | tr ',' ' ' | tr -s ' ')

# ================= tool selection =================
USE=""
if command -v ufw >/dev/null 2>&1; then USE="ufw"
elif command -v firewall-cmd >/dev/null 2>&1; then USE="firewalld"
else
  echo "Neither ufw nor firewalld found."
  echo "Manual: zypper install firewalld && systemctl enable --now firewalld, then re-run."
  exit 1
fi
echo "Firewall tool: $USE"

# ================= ufw path =================
if [[ $USE == "ufw" ]]; then
  echo
  echo "NOTE: ufw reset below wipes existing ufw rules (fresh baseline)."
  read -rp "Proceed with reset + only-required allowlist? [y/N] " a
  [[ $a =~ ^[Yy] ]] || { echo "Aborted."; exit 1; }
  ufw --force reset >/dev/null
  ufw default deny incoming
  ufw default allow outgoing
  for p in $REQ_TCP $EXTRA_TCP; do
    case "$p" in
      *:*) ufw allow "$p"/tcp ;;
      *)   ufw allow "$p/tcp"  ;;
    esac
    echo "allowed $p/tcp"
  done
  ufw --force enable
  echo; echo "=== RESULT ==="; ufw status verbose

# ================= firewalld path (OpenSUSE default) =================
else
  systemctl enable --now firewalld >/dev/null 2>&1 || true
  ZONE=$(firewall-cmd --get-default-zone)
  echo "Operating on zone: $ZONE"
  read -rp "Proceed: strip ALL services/ports from '$ZONE' then allow ONLY required? [y/N] " a
  [[ $a =~ ^[Yy] ]] || { echo "Aborted."; exit 1; }

  # strip every existing service + port from the zone
  for s in $(firewall-cmd --permanent --zone="$ZONE" --list-services); do
    firewall-cmd --permanent --zone="$ZONE" --remove-service="$s" >/dev/null
  done
  for p in $(firewall-cmd --permanent --zone="$ZONE" --list-ports); do
    firewall-cmd --permanent --zone="$ZONE" --remove-port="$p" >/dev/null
  done
  # required + extra (TCP only; add UDP manually if you prove a need)
  for p in $REQ_TCP $EXTRA_TCP; do
    firewall-cmd --permanent --zone="$ZONE" --add-port="$p/tcp" >/dev/null && echo "allowed $p/tcp"
  done
  firewall-cmd --reload

  echo; echo "=== RESULT ==="
  firewall-cmd --zone="$ZONE" --list-all
fi

# ================= post-check: does firewalld match reality? =================
echo
echo "=== SELF-CHECK: required ports actually LISTENING? ==="
for p in $REQ_TCP; do
  if ss -tlnH "( sport = :$p )" 2>/dev/null | grep -q .; then
    echo "  OK    $p/tcp listening"
  else
    echo "  MISS  $p/tcp NOT listening — open in firewall is not enough; the scored service must run on it"
  fi
done
echo
echo "Rollback: restore from $BACKUP / snapshot via Controller (names must be identical)."
echo "Re-run Task: wincheck via 'ss -tulpn' and compare to the required list above."
