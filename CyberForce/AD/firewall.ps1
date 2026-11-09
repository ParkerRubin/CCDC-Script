# ============================================================
# CYBERFORCE 2026 - FIREWALL BASELINE - AD (Windows Server 2022, Domain Controller)
# Required scored inbound (per official AWS doc):
#   LDAP   389/tcp
#   SNMP   161/udp
#   SSH     22/tcp
# DC baseline (domain falls over without these - always applied):
#   TCP 53,88,135,139,389,445,464,636,3268,3269 + RPC dynamic 49152-65535
#   UDP 53,88,123,389,464
# Team access: RDP 3389, WinRM 5985
# Rules of play: NO allow-lists, NO subnet/CIDR blocks.
# Run as Administrator. Every change -> Security Documentation.
# ============================================================
param(
  [switch]$SkipRpcDynamic,       # do not open the RPC dynamic range (breaks AD ops if skipped wrongly)
  [switch]$SkipLegacyDisable     # keep Cast-to-Device / Discovery / RemoteAssist enabled
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "ERROR: Run PowerShell as Administrator." -ForegroundColor Red; exit 1 }

# ---- scored-required ports ----
$RequiredTCP = @(389, 22)             # LDAP, SSH
$RequiredUDP = @(161)                 # SNMP  (UDP! - protocol matters, scoreboard tests UDP)
# ---- DC baseline (baked in, do not edit) ----
$BaselineTCP = @(53,88,135,139,389,445,464,636,3268,3269)
$BaselineUDP = @(53,88,123,389,464)
$RpcRange    = "49152-65535"
# ---- team management ports ----
$TeamTCP = @(3389, 5985)              # RDP, WinRM (unrestricted - allow lists are banned)

$GroupName = "CyberForce2026 - AD"
$BackupDir = "C:\CF-Toolkit\FirewallBackups"
$TS        = Get-Date -Format "yyyyMMdd-HHmmss"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

Write-Host "=== CYBERFORCE FIREWALL - AD / DC ===" -ForegroundColor Cyan

# ---- 1. rollback file ----
$wfw = Join-Path $BackupDir "ad-firewall-$TS.wfw"
netsh advfirewall export "$wfw" | Out-Null
Write-Host "Rollback export: $wfw" -ForegroundColor DarkGray

# ---- 2. profiles: ON, default inbound BLOCK, outbound ALLOW + logging ----
Set-NetFirewallProfile -All -Enabled True `
  -DefaultInboundAction Block -DefaultOutboundAction Allow
netsh advfirewall set allprofiles logging "%SystemRoot%\System32\LogFiles\Firewall\cf_firewall.log" 8192 enable | Out-Null
Write-Host "Profiles: ON | inbound=Block | outbound=Allow | logging enabled"

# ---- 3. replace previous CF rules, create all of them ----
Get-NetFirewallRule -Group $GroupName -ErrorAction SilentlyContinue | Remove-NetFirewallRule

foreach ($ports in @(
    @{ List = $RequiredTCP  + ($BaselineTCP | Where-Object { $_ -notin $RequiredTCP });  Proto = 'TCP'; Label = 'REQUIRED+DC' },
    @{ List = $RequiredUDP  + ($BaselineUDP | Where-Object { $_ -notin $RequiredUDP });  Proto = 'UDP'; Label = 'REQUIRED+DC' }
)) {
  foreach ($p in ($ports.List | Sort-Object -Unique)) {
    New-NetFirewallRule -DisplayName "CF $($ports.Label) $($ports.Proto) $p" -Group $GroupName -Direction Inbound `
      -Protocol $ports.Proto -LocalPort $p -Action Allow -Profile Any | Out-Null
    Write-Host "  allowed $($ports.Proto)/$p" -ForegroundColor Green
  }
}
if (-not $SkipRpcDynamic) {
  New-NetFirewallRule -DisplayName "CF DC RPC DYNAMIC" -Group $GroupName -Direction Inbound `
    -Protocol TCP -LocalPort $RpcRange -Action Allow -Profile Any | Out-Null
  Write-Host "  allowed TCP/$RpcRange (RPC dynamic - needed for AD replication/MMC)" -ForegroundColor Green
}
foreach ($p in $TeamTCP) {
  New-NetFirewallRule -DisplayName "CF TEAM TCP $p" -Group "$GroupName (team)" -Direction Inbound `
    -Protocol TCP -LocalPort $p -Action Allow -Profile Any | Out-Null
  Write-Host "  allowed TCP/$p (team access)" -ForegroundColor DarkGreen
}

# ---- 4. disable noisy consumer rules ----
if (-not $SkipLegacyDisable) {
  foreach ($pat in @('Network Discovery*','Cast to Device*','Remote Assistance*','mDNS*','SSDP*')) {
    Get-NetFirewallRule -DisplayName $pat -ErrorAction SilentlyContinue |
      Where-Object { $_.Group -notlike "$GroupName*" } |
      Disable-NetFirewallRule -ErrorAction SilentlyContinue
  }
  Write-Host "Legacy consumer rules disabled (use -SkipLegacyDisable to keep)" -ForegroundColor DarkGray
}

# ---- 5. report ----
Write-Host "`n=== CF RULES ACTIVE ===" -ForegroundColor Cyan
Get-NetFirewallRule -Group $GroupName -Enabled True |
  ForEach-Object { $pr = ($_ | Get-NetFirewallPortFilter); "{0,-50} {1}/{2}" -f $_.DisplayName, $_.Protocol, $pr.LocalPort } |
  Sort-Object | Out-Host

Write-Host "`nPost-check:" -ForegroundColor Yellow
Write-Host " - LDAP test: from team box  ldapsearch / dsquery to 10.0.x.141:389 (scored)"
Write-Host " - SNMP test: snmpwalk community 'public'? (scored, UDP 161)"
Write-Host " - domain logons + MMC still work? (DC baseline did its job)"
Write-Host " - run snapshot.ps1 + wininfo.ps1 to record the new baseline"
