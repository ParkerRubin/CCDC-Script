# ============================================================
# CYBERFORCE 2026 - FIREWALL BASELINE - MAIL-FILE (Windows Server 2019)
# Required scored inbound (per official AWS doc):
#   HFS   1080/tcp
#   SMTP    25/tcp
#   SSH      22/tcp
# Team access: RDP 3389, WinRM 5985
# Rules of play: NO allow-lists, NO subnet/CIDR blocks. Block
# everything else inbound; leave existing rules in place unless
# you verify none of them matter (they must go in SecDoc).
# Run as Administrator. Every change -> Security Documentation.
# ============================================================
param(
  [switch]$SkipLegacyDisable   # keep Cast-to-Device / Discovery / RemoteAssist rules enabled
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "ERROR: Run PowerShell as Administrator." -ForegroundColor Red; exit 1 }

# ---- required scored ports (DO NOT REMOVE; changes go in SecDoc) ----
$RequiredTCP = @(25, 1080, 22)      # SMTP, HFS, SSH
$RequiredUDP = @()
# ---- team management ports ----
$TeamTCP = @(3389, 5985)            # RDP, WinRM (unrestricted - allow lists are banned)

$GroupName  = "CyberForce2026 - MailFile"
$BackupDir  = "C:\CF-Toolkit\FirewallBackups"
$TS         = Get-Date -Format "yyyyMMdd-HHmmss"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

Write-Host "=== CYBERFORCE FIREWALL - MAIL-FILE ===" -ForegroundColor Cyan

# ---- 1. rollback file ----
$wfw = Join-Path $BackupDir "mailfile-firewall-$TS.wfw"
netsh advfirewall export "$wfw" | Out-Null
Write-Host "Rollback export: $wfw" -ForegroundColor DarkGray

# ---- 2. profiles: ON, default inbound BLOCK, outbound ALLOW + logging ----
Set-NetFirewallProfile -All -Enabled True `
  -DefaultInboundAction Block -DefaultOutboundAction Allow
netsh advfirewall set allprofiles logging "%SystemRoot%\System32\LogFiles\Firewall\cf_firewall.log" 8192 enable | Out-Null
Write-Host "Profiles: ON | inbound=Block | outbound=Allow | logging enabled"

# ---- 3. replace previous CF rules, create required ones ----
Get-NetFirewallRule -Group $GroupName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
foreach ($p in $RequiredTCP) {
  New-NetFirewallRule -DisplayName "CF REQUIRED TCP $p" -Group $GroupName -Direction Inbound `
    -Protocol TCP -LocalPort $p -Action Allow -Profile Any | Out-Null
  Write-Host "  allowed TCP/$p (required)" -ForegroundColor Green
}
foreach ($p in $RequiredUDP) {
  New-NetFirewallRule -DisplayName "CF REQUIRED UDP $p" -Group $GroupName -Direction Inbound `
    -Protocol UDP -LocalPort $p -Action Allow -Profile Any | Out-Null
  Write-Host "  allowed UDP/$p (required)" -ForegroundColor Green
}
foreach ($p in $TeamTCP) {
  New-NetFirewallRule -DisplayName "CF TEAM TCP $p" -Group "$GroupName (team)" -Direction Inbound `
    -Protocol TCP -LocalPort $p -Action Allow -Profile Any | Out-Null
  Write-Host "  allowed TCP/$p (team access)" -ForegroundColor DarkGreen
}

# ---- 4. disable noisy consumer rules (not scored; reduce surface) ----
if (-not $SkipLegacyDisable) {
  $patterns = @('Network Discovery*','Cast to Device*','Remote Assistance*','mDNS*','SSDP*')
  foreach ($pat in $patterns) {
    Get-NetFirewallRule -DisplayName $pat -ErrorAction SilentlyContinue |
      Where-Object { $_.Group -notlike "$GroupName*" } |
      Disable-NetFirewallRule -ErrorAction SilentlyContinue
  }
  Write-Host "Legacy consumer rules disabled (use -SkipLegacyDisable to keep)" -ForegroundColor DarkGray
}

# ---- 5. report ----
Write-Host "`n=== ACTIVE INBOUND ALLOW RULES ===" -ForegroundColor Cyan
Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow |
  ForEach-Object { $pr = ($_ | Get-NetFirewallPortFilter); "{0,-55} {1}/{2}" -f $_.DisplayName, $_.Protocol, $pr.LocalPort } |
  Sort-Object | Out-Host

Write-Host "`nPost-check:" -ForegroundColor Yellow
Write-Host " - from team box: test 25/1080 reaches this box + RDP works"
Write-Host " - verify scoreboard still connects (add back ONLY individual rules if not)"
Write-Host " - run snapshot.ps1 + wininfo.ps1 to record the new baseline"
