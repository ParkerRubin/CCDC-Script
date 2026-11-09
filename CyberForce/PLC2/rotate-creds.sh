#!/usr/bin/env bash
# ============================================================
# CYBERFORCE 2026 — ROTATE CREDS — PLC2 (Debian 13, DNP3)
# *** ASSUME-BREACH MACHINE — EXTREME CAUTION ***
# blueteam:BlueTeam2026! is PUBLIC. Rotate day one — it does not
# stop Red (they're already in; that's the exercise), it stops
# OTHER teams if creds ever leak and shows SecDoc professionalism.
# NEVER touch: SCORE1, SCORE2, PATCH. Also NEVER touch:
#   - dnp3.service (Rust service — do not remove/alter)
#   - the MQTT broker config beyond listing it
# This box is your main forensic evidence source for the 1000
# Red attack-chain points — every audit line below is gold.
# ============================================================
set -u

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo (sudo bash rotate-creds.sh)" >&2
  exit 1
fi

PROTECTED="SCORE1|SCORE2|PATCH|historian|root"
TS=$(date +%Y%m%d-%H%M%S)
CREDFILE="$HOME/cf-creds-$TS.txt"
touch "$CREDFILE" && chmod 600 "$CREDFILE"

log() { echo "$1" | tee -a "$CREDFILE"; }
genpw() { tr -dc 'A-HJ-NP-Za-km-z2-9' < /dev/urandom | head -c 20; echo; }

log "== CF rotate-creds — PLC2 (ASSUME-BREACH) — $TS =="

# ---------------- 1. user audit + persistence hunt ----------------
log ""
log "--- Local human accounts (uid>=1000) ---"
getent passwd | awk -F: '$3>=1000 && $3<60000 {printf "  %-16s shell=%s home=%s\n",$1,$7,$6}' | tee -a "$CREDFILE"
log ""
log "--- Accounts with usable shells (report EVERY suspicious one to Red report) ---"
getent passwd | awk -F: '$7 ~ /(bash|sh|zsh)$/ {printf "  %-16s %s\n",$1,$7}' | tee -a "$CREDFILE"
log ""
log "--- sudoers additions ---"
grep -Rns "" /etc/sudoers /etc/sudoers.d 2>/dev/null | grep -vE '^\S*#|Defaults' | tee -a "$CREDFILE"
log ""
log "--- root-equivalent uid0 ---"
getent passwd | awk -F: '$3==0 {print "  "$1}' | tee -a "$CREDFILE"
log ""
log "--- SSH keys (persistence evidence) ---"
for d in /root /home/*; do
  [[ -f "$d/.ssh/authorized_keys" ]] && awk -v h="$d" '{print "  "h"$0"}' "$d/.ssh/authorized_keys" | tee -a "$CREDFILE"
done
log ""
log "--- running services (baseline for drift) ---"
systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{printf "  %s\n",$1}' | tee -a "$CREDFILE"

# ---------------- 2. rotate blueteam ----------------
echo
read -rp "Rotate the linux user 'blueteam'? [Y/n] " a
if [[ ${a:-Y} =~ ^[Yy]$ ]]; then
  NEWPW=$(genpw); NEWPW="${NEWPW}Pa1"
  echo "blueteam:${NEWPW}" | chpasswd && log "ROTATED  linux blueteam -> $NEWPW"
fi

# ---------------- 3. MQTT broker exposure note ----------------
log ""
log "--- MQTT (1883) config snapshot ---"
grep -Rns "allow_anonymous\|password_file\|listener" /etc/mosquitto/ 2>/dev/null | tee -a "$CREDFILE" || log "  (no mosquitto config found)"

echo
log "=== DONE. Creds saved in: $CREDFILE (chmod 600) ==="
echo "Handler: everything below the ROTATED markers = Red-team evidence for the assume-breach report."
