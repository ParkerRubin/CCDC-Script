# ============================================================
# CYBERFORCE 2026 - FIREWALL BASELINE - HMI (Windows Server 2019, ASSUME-BREACH)
# *** ASSUME-BREACH MACHINE - EXTREME CAUTION ***
# Required scored inbound (per official AWS doc):
#   Ignition Gateway   8088/tcp
#   Data Historian    3306/tcp  (MySQL - creds historian / NEVER rotate)
# Team access: RDP 3389 (this box HAS NO SSH - RDP is the only way in)
# !!! RULES FOR THIS BOX !!!
#  - Red team ALREADY has access; anything that stops them or the
#    scoreboard reaching 8088/3306 costs points.
#  - Monitoring tools at your own risk only.
#  - No IP blocking of any kind. Nothing scored may be filtered.
# Requires -ConfirmAB switch or refuses to run. A firewall here
# mostly serves as logging; consider -ReportOnly!
# ============================================================
param(
  [switch]$ConfirmAB,     # required
  [switch]$ReportOnly     # no changes - just show current exposure + rules
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "ERROR: Run PowerShell as Administrator." -ForegroundColor Red; exit 1 }

if (-not $ReportOnly -and -not $ConfirmAB) {
  Write-Host "ASSUME-BREACH BOX. Run with -ConfirmAB to apply, or -ReportOnly to just inspect." -ForegroundColor Red
  exit 1
}

$RequiredTCP = @(8088, 3306)      # Ignition, MySQL historian
$TeamTCP     = @(3389)            # RDP only (no SSH on this box)
$GroupName   = "CyberForce2026 - HMI"
$BackupDir   = "C:\CF-Toolkit\FirewallBackups"
$TS          = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "=== CYBERFORCE FIREWALL - HMI (ASSUME-BREACH) ===" -ForegroundColor Cyan

if ($ReportOnly) {
  Write-Host "`n=== listening ports ===" -ForegroundColor Cyan
  Get-NetTCPConnection -State Listen | ForEach-Object {
    $pn = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name
    "{0,-14} {1}/{2}" -f $_.LocalAddress, $_.LocalPort, $pn
  } | Sort-Object | Out-Host
  Write-Host "`n=== enabled inbound allow rules (non-OS noise highlighted last run via wininfo) ===" -ForegroundColor Cyan
  Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow |
    ForEach-Object { $pr = ($_ | Get-NetFirewallPortFilter); "{0,-55} {1}/{2}" -f $_.DisplayName, $_.Protocol, $pr.LocalPort } |
    Sort-Object | Out-Host
  Write-Host "`nNo changes made (-ReportOnly)." -ForegroundColor Green
  exit 0
}

$wfw = Join-Path $BackupDir "hmi-firewall-$TS.wfw"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
netsh advfirewall export "$wfw" | Out-Null
Write-Host "Rollback export: $wfw" -ForegroundColor DarkGray

Set-NetFirewallProfile -All -Enabled True `
  -DefaultInboundAction Block -DefaultOutboundAction Allow
netsh advfirewall set allprofiles logging "%SystemRoot%\System32\LogFiles\Firewall\cf_firewall.log" 8192 enable | Out-Null
Write-Host "Profiles: ON | inbound=Block | outbound=Allow | logging enabled"

Get-NetFirewallRule -Group $GroupName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
foreach ($p in $RequiredTCP) {
  New-NetFirewallRule -DisplayName "CF REQUIRED TCP $p" -Group $GroupName -Direction Inbound `
    -Protocol TCP -LocalPort $p -Action Allow -Profile Any | Out-Null
  Write-Host "  allowed TCP/$p (required)" -ForegroundColor Green
}
foreach ($p in $TeamTCP) {
  New-NetFirewallRule -DisplayName "CF TEAM TCP $p" -Group "$GroupName (team)" -Direction Inbound `
    -Protocol TCP -LocalPort $p -Action Allow -Profile Any | Out-Null
  Write-Host "  allowed TCP/$p (team access - RDP)" -ForegroundColor DarkGreen
}

Write-Host "`nPost-check:" -ForegroundColor Yellow
Write-Host " - Ignition gate: http://10.0.x.142:8088 reachable from team box (Blue + ICS)"
Write-Host " - MySQL historian reachable on 3306 (scored; historian creds NEVER change)"
Write-Host " - RDP still works - this is your ONLY way onto this box"
Write-Host " - verify Red team can still reach 8088/3306 (they are 'already inside' by design)"
Write-Host " - snapshot.ps1 + wininfo.ps1 to record the baseline"
