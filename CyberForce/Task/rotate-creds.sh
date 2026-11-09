#!/usr/bin/env bash
# ============================================================
# CYBERFORCE 2026 — ROTATE CREDS — TASK (OpenSUSE Leap)
# blueteam:BlueTeam2026! is published in the PUBLIC comp repo.
# Rotate day one (Nov 2), before Red team ever talks to you.
# NEVER touch: SCORE1, SCORE2, PATCH (+ MySQL 'historian' lives
# on HMI, not here - listed only as a guard).
# Task-box extras handled here:
#   - MySQL 'blueteam' DB account (scored service on 3306)
#   - Samba users (139/445)
#   - HTTP/Wordpress site on this box reads MySQL config - the
#     script greps for the old password so you know what to update
# ============================================================
set -u

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo (sudo bash rotate-creds.sh)" >&2
  exit 1
fi

PROTECTED="SCORE1|SCORE2|PATCH|historian|root"
TS=$(date +%Y%m%d-%H%M%S)
CREDFILE="$HOME/cf-creds-$TS.txt"
chmod 600 "$CREDFILE" 2>/dev/null || touch "$CREDFILE" && chmod 600 "$CREDFILE"

log() { echo "$1" | tee -a "$CREDFILE"; }
genpw() { tr -dc 'A-HJ-NP-Za-km-z2-9' < /dev/urandom | head -c 20; echo; }

log "== CF rotate-creds — TASK — $TS =="

# ---------------- 1. local user audit ----------------
log ""
log "--- Local human accounts (uid>=1000) ---"
getent passwd | awk -F: '$3>=1000 && $3<60000 {printf "  %-16s shell=%s home=%s\n",$1,$7,$6}' | tee -a "$CREDFILE"
log ""
log "--- Accounts with usable shells (audit these closely) ---"
getent passwd | awk -F: '$7 ~ /(bash|sh|zsh)$/ {printf "  %-16s %s\n",$1,$7}' | tee -a "$CREDFILE"

# ---------------- 2. rotate blueteam ----------------
echo
read -rp "Rotate the linux user 'blueteam'? [Y/n] " a
if [[ ${a:-Y} =~ ^[Yy]$ ]]; then
  NEWPW=$(genpw); NEWPW="${NEWPW}Pa1"
  echo "blueteam:${NEWPW}" | chpasswd && log "ROTATED  linux blueteam -> $NEWPW"
  echo "NOTE: your CURRENT ssh session stays authed. New sessions need the new password."
fi

# ---------------- 3. MySQL blueteam (scored 3306) ----------------
echo
read -rp "Rotate MySQL 'blueteam' DB account? (scored service!) [y/N] " a
if [[ $a =~ ^[Yy]$ ]]; then
  OLDPW="BlueTeam2026!"
  read -rp "Current MySQL blueteam password (enter if still default): " MPW
  MPW=${MPW:-$OLDPW}
  NEWMYSQL=$(genpw); NEWMYSQL="${NEWMYSQL}Pa1"
  HOSTS=$(mysql -N -s -ublueteam -p"$MPW" -e "SELECT Host FROM mysql.user WHERE User='blueteam';" 2>/dev/null) || {
    echo "Could not auth as MySQL blueteam — check creds, try again."; }
  if [[ -n ${HOSTS:-} ]]; then
    while read -r h; do
      mysql -ublueteam -p"$MPW" -e "ALTER USER 'blueteam'@'${h}' IDENTIFIED BY '${NEWMYSQL}';" 2>/dev/null \
        && log "ROTATED  mysql blueteam@${h} -> $NEWMYSQL"
    done <<< "$HOSTS"
    echo "IMPORTANT: find apps using the old DB password:"
    grep -rn --exclude-dir=proc --exclude-dir=sys -l "BlueTeam2026" /var/www /srv /etc 2>/dev/null | tee -a "$CREDFILE"
    echo "Update every config file above or the website/MySQL scored service breaks."
  fi
fi

# ---------------- 4. Samba users ----------------
if command -v pdbedit >/dev/null 2>&1; then
  echo
  SMBLIST=$(pdbedit -L 2>/dev/null | awk -F: '{print $1}')
  echo "Samba users: ${SMBLIST:-none}"
  log ""
  log "--- Samba users ---"
  for u in $SMBLIST; do
    case "$u" in $PROTECTED) echo "  skip (protected): $u"; continue;; esac
    read -rp "  rotate samba user '$u'? [y/N] " b
    if [[ $b =~ ^[Yy]$ ]]; then
      NP=$(genpw); NP="${NP}Pa1"
      printf '%s\n%s\n' "$NP" "$NP" | smbpasswd -s "$u" >/dev/null 2>&1 && log "ROTATED  samba $u -> $NP"
    fi
  done
fi

# ---------------- summary ----------------
echo
log ""
log "=== DONE. Creds saved in: $CREDFILE (chmod 600) ==="
echo "Next: run firewall.sh, then snapshot (pwsh if available) / manual triage."
echo "Record every change -> Security Documentation."
