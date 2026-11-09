# ============================================================
# CYBERFORCE 2026 - ROTATE CREDS - HMI (Windows Server 2019, ASSUME-BREACH)
# blueteam:BlueTeam2026! is PUBLIC - and this box is the Crown
# jewel: Ignition gateway + MySQL data historian. Rotate the
# WINDOWS accounts day one. PERMANENT DO-NOT-TOUCH:
#   - MySQL account 'historian' (CyberForce2026!) - scored service
#   - SCORE1 / SCORE2 / PATCH
# HMI extras handled here:
#   - Ignition Gateway login (blueteam:BlueTeam2026!) -> guided manual
#   - historian account verified untouched
# ============================================================
param(
  [string]$User = "blueteam",
  [string]$RotateToo = ""
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "ERROR: Run PowerShell as Administrator." -ForegroundColor Red; exit 1 }

$Protected = @('SCORE1','SCORE2','PATCH')
$Dir = "C:\CF-Toolkit\Creds"
$TS  = Get-Date -Format "yyyyMMdd-HHmmss"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Out = Join-Path $Dir "cred-sheet-hmi-$TS.txt"

function New-Password {
  $c = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'
  $p = -join (1..22 | ForEach-Object { $c[(Get-Random -Maximum $c.Length)] })
  "$p`#Pa1"
}

Add-Content $Out "== CF rotate-creds -- HMI (ASSUME-BREACH) -- $TS =="

# ---- 1. local user audit ----
Add-Content $Out "`n-- Local users --"
Get-LocalUser | ForEach-Object {
  Add-Content $Out ("  {0,-20} Enabled={1,-6} PwdRequired={2}" -f $_.Name, $_.Enabled, $_.PasswordRequired)
}
Add-Content $Out "`n-- Administrators group --"
Get-LocalGroupMember Administrators | ForEach-Object { Add-Content $Out "  $($_.Name)" }

# ---- 2. rotate local accounts ----
foreach ($u in (@($User) + ($RotateToo -split ',' | Where-Object { $_ }))) {
  if ($Protected -contains $u) { Write-Host "SKIP protected account: $u" -ForegroundColor Red; continue }
  if (-not (Get-LocalUser -Name $u -ErrorAction SilentlyContinue)) { Write-Host "No such local user: $u" -ForegroundColor DarkGray; continue }
  $pw = New-Password
  Set-LocalUser -Name $u -Password (ConvertTo-SecureString $pw -AsPlainText -Force)
  Add-Content $Out "ROTATED  local $u -> $pw"
  Write-Host "ROTATED  local $u" -ForegroundColor Green
}

# ---- 3. MySQL historian MUST NOT rotate - just verify ----
Write-Host ""
Write-Host "Verify the MySQL 'historian' account is untouched (NEVER rotate it):" -ForegroundColor Yellow
try {
  $mysql = "C:\Program Files\MySQL\MySQL Server*\bin\mysql.exe"
  $bin = Get-ChildItem -Path $mysql -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($bin) {
    & $bin.FullName -uhistorian -pCyberForce2026! -e "SELECT COUNT(*) AS ok FROM information_schema.schemata WHERE schema_name='historian';" | Out-Host
    Write-Host "  historian login still WORKS - leave as is." -ForegroundColor Green
  } else { Write-Host "  mysql client not found at default path - verify via Workbench/service" }
} catch { Write-Host "  verify manually (creds historian: CyberForce2026!)" }

# ---- 4. Ignition gateway creds ----
Write-Host ""
Write-Host "Ignition Gateway (8088) uses blueteam:BlueTeam2026! - PUBLIC. Rotate it:" -ForegroundColor Yellow
Write-Host "  1. http://localhost:8088  -> login blueteam:BlueTeam2026!"
Write-Host "  2. Config tab -> Web Interface -> security/users -> change blueteam password"
Write-Host "  3. ALSO update Designer Launcher + Perspective Workstation saved logins on this box"
Write-Host "  4. Confirm the PLC OPC-UA / GW connections still function after the change"
$igpw = Read-Host "Type the NEW Ignition password (blank=skip)"
if ($igpw) { Add-Content $Out "MANUAL   ignition gateway blueteam -> $igpw" }

# ---- 5. default-password landmines ----
$hits = Get-ChildItem -Path 'C:\Program Files\Inductive Automation','C:\Users\blueteam' -Recurse -Include *.ini,*.config,*.xml,*.cmd,*.txt -ErrorAction SilentlyContinue |
        Select-String -Pattern 'BlueTeam2026' -List -ErrorAction SilentlyContinue
if ($hits) { $hits.Path | ForEach-Object { Write-Host "  FOUND: $_" -ForegroundColor Magenta; Add-Content $Out "GREPHIT  $_" } }

Add-Content $Out "`n== DONE. Sheet: $Out =="
Write-Host ""
Write-Host "Sheet saved: $Out" -ForegroundColor Cyan
Write-Host "NOTE: rotating the Windows 'blueteam' DOES NOT change the Ignition engine internals;"
Write-Host "      if the Ignition DNP3/OPC-UA drivers use OS creds, re-check their connections."
Write-Host "Next: firewall.ps1 -ReportOnly first!, then snapshot.ps1."
