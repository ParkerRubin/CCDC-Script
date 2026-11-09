# ============================================================
# CYBERFORCE 2026 - ROTATE CREDS - MAIL-FILE (Windows Server 2019)
# blueteam:BlueTeam2026! is PUBLIC in the comp repo. Rotate day
# one (Nov 2). NEVER touch SCORE1/SCORE2/PATCH (scoring SSH/RDP).
# Mail-File extras handled here:
#   - audit + rotate local accounts (blueteam default)
#   - HFS (Rejetto) app password -> guided manual change
#   - SMTP: uses local accounts by default; same rotation covers it
#   - reminds: this box also SMB/shares? -> check shares manually
# ============================================================
param(
  [string]$User = "blueteam",
  [string]$RotateToo = ""    # comma-separated extra local users to rotate, e.g. "hfsuser,svc-ftp"
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "ERROR: Run PowerShell as Administrator." -ForegroundColor Red; exit 1 }

$Protected = @('SCORE1','SCORE2','PATCH')          # NEVER rotate these
$Dir = "C:\CF-Toolkit\Creds"
$TS  = Get-Date -Format "yyyyMMdd-HHmmss"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Out = Join-Path $Dir "cred-sheet-mailfile-$TS.txt"

# ASCII-only password generator (no ambiguous chars), meets complexity
function New-Password {
  $c = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'
  $p = -join (1..22 | ForEach-Object { $c[(Get-Random -Maximum $c.Length)] })
  "$p`#Pa1"
}

Add-Content $Out "== CF rotate-creds -- MAIL-FILE -- $TS =="

# ---- 1. local user audit ----
Add-Content $Out "`n-- Local users --"
Get-LocalUser | ForEach-Object {
  Add-Content $Out ("  {0,-20} Enabled={1,-6} PwdRequired={2}" -f $_.Name, $_.Enabled, $_.PasswordRequired)
}
Add-Content $Out "`n-- Administrators group --"
Get-LocalGroupMember Administrators | ForEach-Object { Add-Content $Out "  $($_.Name)" }

# ---- 2. rotate ----
foreach ($u in (@($User) + ($RotateToo -split ',' | Where-Object { $_ }))) {
  if ($Protected -contains $u) { Write-Host "SKIP protected account: $u" -ForegroundColor Red; continue }
  if (-not (Get-LocalUser -Name $u -ErrorAction SilentlyContinue)) { Write-Host "No such local user: $u" -ForegroundColor DarkGray; continue }
  $pw = New-Password
  Set-LocalUser -Name $u -Password (ConvertTo-SecureString $pw -AsPlainText -Force)
  Add-Content $Out "ROTATED  local $u -> $pw"
  Write-Host "ROTATED  local $u" -ForegroundColor Green
}

# ---- 3. HFS app creds (1080) ----
Write-Host ""
Write-Host "HFS (Rejetto, files over the web) on :1080 has its OWN account list in the app." -ForegroundColor Yellow
Write-Host "  1. Open the HFS app/console on this box -> 'Menu' -> 'User accounts'"
Write-Host "  2. Change every account password; record in the cred sheet"
Write-Host "  3. Confirm http://<this-ip>:1080 still serves after the change"
$hfspw = Read-Host "Type the NEW HFS account password after the UI change (blank=skip)"
if ($hfspw) { Add-Content $Out "MANUAL   HFS app account -> $hfspw" }

# ---- 4. old-password landmines (services/configs still using defaults) ----
Write-Host ""
Write-Host "Checking for services/configs still referencing the default password..." -ForegroundColor Yellow
$hits = Get-ChildItem -Path 'C:\inetpub','C:\Program Files','C:\Program Files (x86)','C:\Users\blueteam' -Recurse -Include *.config,*.ini,*.conf,*.txt,*.xml -ErrorAction SilentlyContinue |
        Select-String -Pattern 'BlueTeam2026' -List -ErrorAction SilentlyContinue
if ($hits) { $hits.Path | ForEach-Object { Write-Host "  FOUND: $_" -ForegroundColor Magenta; Add-Content $Out "GREPHIT  $_" } }
else { Write-Host "  none found" }

Add-Content $Out "`n== DONE. Sheet: $Out =="
Write-Host ""
Write-Host "Sheet saved: $Out  (reconnect to RDP/SSH with the NEW password next time)" -ForegroundColor Cyan
Write-Host "Next: firewall.ps1, then snapshot.ps1 and wininfo.ps1."
