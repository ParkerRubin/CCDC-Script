param(
  [switch]$ActiveProfilesOnly
)

# ================== EDIT THESE ==================
# AD / Domain Controller firewall. The DC baseline ports are baked in below.
# You do NOT edit ports here - run the script and add any EXTRA service ports
# at the prompt. The baseline is always applied on top of what you type.
$EnableRDP = $true
$RestrictRDP = $true
$LogFolder = "$env:SystemRoot\System32\LogFiles\Firewall"

$KeepExistingInboundRules = $true

# AD/DC baseline (open these or the domain falls over). 3389 is intentionally
# NOT here - RDP is handled separately below so it stays source-restricted.
$BaselineTCP = @(53,88,135,139,389,445,464,636,3268,3269)
$BaselineUDP = @(53,88,123,389,464)

# AD RPC uses a high dynamic range. Needed for replication / MMC / domain ops.
$EnableRpcDynamic = $true          # opens 49152-65535/TCP
$RpcDynamicRange  = "49152-65535"
# =================================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
  Write-Host "ERROR: Run PowerShell as Administrator." -ForegroundColor Red
  exit 1
}

# ---- Interactive port prompt ----
# Returns a sorted, de-duped int[] of valid ports (1-65535). Blank = none.
function Read-PortList {
  param([string]$Label)
  Write-Host ""
  Write-Host "Enter EXTRA inbound $Label ports to allow, comma-separated (blank = none)." -ForegroundColor Cyan
  Write-Host "These are ADDED to the AD baseline. Examples: 1433   or   8080,9000" -ForegroundColor DarkGray
  $raw = Read-Host "$Label ports"
  if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
  $ports = @()
  foreach ($tok in ($raw -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })) {
    if ($tok -match '^\d{1,5}$' -and [int]$tok -ge 1 -and [int]$tok -le 65535) {
      $ports += [int]$tok
    } else {
      Write-Host "Ignoring invalid port: $tok" -ForegroundColor Red
    }
  }
  return ($ports | Sort-Object -Unique)
}

Write-Host "=== WRCCDC AD/DC Firewall Baseline ===" -ForegroundColor Cyan
Write-Host "Baseline TCP: $($BaselineTCP -join ', ')" -ForegroundColor DarkCyan
Write-Host "Baseline UDP: $($BaselineUDP -join ', ')" -ForegroundColor DarkCyan
if ($EnableRpcDynamic) { Write-Host "Baseline RPC: $RpcDynamicRange/TCP" -ForegroundColor DarkCyan }

$extraTCP = Read-PortList -Label "TCP"
$extraUDP = Read-PortList -Label "UDP"

$AllowedInboundTCP = ($BaselineTCP + $extraTCP | Sort-Object -Unique)
$AllowedInboundUDP = ($BaselineUDP + $extraUDP | Sort-Object -Unique)

Write-Host ""
Write-Host "TCP allowed: $($AllowedInboundTCP -join ', ')" -ForegroundColor Green
Write-Host "UDP allowed: $($AllowedInboundUDP -join ', ')" -ForegroundColor Green

# ---- Interactive RDP source prompt ----
$RdpAllowedRemoteAddresses = @()
if ($EnableRDP -and $RestrictRDP) {
  Write-Host ""
  Write-Host "Enter allowed RDP source IP(s)/CIDR range(s), comma-separated." -ForegroundColor Cyan
  Write-Host "Examples: 10.0.5.10  or  10.0.5.0/24,192.168.1.50" -ForegroundColor DarkGray
  Write-Host "Leave blank to fall back to RFC1918 private ranges." -ForegroundColor DarkGray
  $rdpInput = Read-Host "RDP allowed sources"

  if ([string]::IsNullOrWhiteSpace($rdpInput)) {
    $RdpAllowedRemoteAddresses = @("10.0.0.0/8","172.16.0.0/12","192.168.0.0/16")
    Write-Host "No input given, defaulting to RFC1918 ranges." -ForegroundColor Yellow
  } else {
    $candidates = $rdpInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    $ipOrCidrPattern = '^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$'
    $valid = @()
    $invalid = @()
    foreach ($c in $candidates) {
      if ($c -match $ipOrCidrPattern) { $valid += $c } else { $invalid += $c }
    }
    if ($invalid.Count -gt 0) {
      Write-Host "Ignoring invalid entries: $($invalid -join ', ')" -ForegroundColor Red
    }
    if ($valid.Count -eq 0) {
      Write-Host "No valid entries parsed, defaulting to RFC1918 ranges." -ForegroundColor Yellow
      $RdpAllowedRemoteAddresses = @("10.0.0.0/8","172.16.0.0/12","192.168.0.0/16")
    } else {
      $RdpAllowedRemoteAddresses = $valid
    }
  }
  Write-Host "RDP will be restricted to: $($RdpAllowedRemoteAddresses -join ', ')" -ForegroundColor Green
  Write-Host ""
}

$profilesToApply = @("Domain","Private","Public")
if ($ActiveProfilesOnly) {
  try {
    $cat = (Get-NetConnectionProfile -ErrorAction Stop | Select-Object -First 1).NetworkCategory
    if ($cat -eq "DomainAuthenticated") { $profilesToApply = @("Domain") }
    elseif ($cat -eq "Private") { $profilesToApply = @("Private") }
    elseif ($cat -eq "Public") { $profilesToApply = @("Public") }
  } catch {
    $profilesToApply = @("Domain","Private","Public")
  }
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $env:USERPROFILE "Desktop\CCDC\firewall"
if (!(Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
$backupPath = Join-Path $backupDir "fwbackup_ad_$ts.wfw"
Write-Host "[1/7] Exporting firewall policy to $backupPath"
try { netsh advfirewall export $backupPath | Out-Null } catch {}

Write-Host "[2/7] Enabling firewall + setting defaults (Inbound=Block, Outbound=Allow)"
try {
  Set-NetFirewallProfile -Profile $profilesToApply `
    -Enabled True `
    -DefaultInboundAction Block `
    -DefaultOutboundAction Allow `
    -AllowInboundRules $KeepExistingInboundRules `
    -AllowLocalFirewallRules True `
    -AllowUnicastResponseToMulticast False `
    -NotifyOnListen True | Out-Null
} catch {}

Write-Host "[3/7] Configuring firewall logging"
try {
  New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
  Set-NetFirewallProfile -Profile $profilesToApply `
    -LogAllowed True `
    -LogBlocked True `
    -LogMaxSizeKilobytes 32767 `
    -LogFileName "$LogFolder\pfirewall.log" | Out-Null
} catch {}

Write-Host "[4/7] Removing old WRCCDC_* rules (if any)"
try {
  Get-NetFirewallRule -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "WRCCDC_*" } |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue
} catch {}

Write-Host "[5/7] Creating inbound allow rules (AD baseline + extras)"

foreach ($p in $AllowedInboundTCP) {
  try {
    New-NetFirewallRule `
      -DisplayName "WRCCDC_TCP_In_$p" `
      -Direction Inbound -Action Allow -Enabled True `
      -Protocol TCP -LocalPort $p `
      -Profile Domain,Private,Public `
      -EdgeTraversalPolicy Block | Out-Null
  } catch {}
}

foreach ($p in $AllowedInboundUDP) {
  try {
    New-NetFirewallRule `
      -DisplayName "WRCCDC_UDP_In_$p" `
      -Direction Inbound -Action Allow -Enabled True `
      -Protocol UDP -LocalPort $p `
      -Profile Domain,Private,Public `
      -EdgeTraversalPolicy Block | Out-Null
  } catch {}
}

if ($EnableRpcDynamic) {
  try {
    New-NetFirewallRule `
      -DisplayName "WRCCDC_TCP_In_RPC_Dynamic" `
      -Direction Inbound -Action Allow -Enabled True `
      -Protocol TCP -LocalPort $RpcDynamicRange `
      -Profile Domain,Private,Public `
      -EdgeTraversalPolicy Block | Out-Null
  } catch {}
}

if ($EnableRDP) {
  Write-Host "[6/7] RDP enabled: allowing TCP/3389"
  if ($RestrictRDP -and $RdpAllowedRemoteAddresses.Count -gt 0) {
    try {
      New-NetFirewallRule `
        -DisplayName "WRCCDC_RDP_3389_Restricted" `
        -Direction Inbound -Action Allow -Enabled True `
        -Protocol TCP -LocalPort 3389 `
        -RemoteAddress $RdpAllowedRemoteAddresses `
        -Profile Domain,Private,Public `
        -EdgeTraversalPolicy Block | Out-Null
    } catch {}
  } else {
    try {
      New-NetFirewallRule `
        -DisplayName "WRCCDC_RDP_3389" `
        -Direction Inbound -Action Allow -Enabled True `
        -Protocol TCP -LocalPort 3389 `
        -Profile Domain,Private,Public `
        -EdgeTraversalPolicy Block | Out-Null
    } catch {}
  }
} else {
  Write-Host "[6/7] RDP not allowed: blocking TCP/3389 (firewall only)"
  try {
    New-NetFirewallRule `
      -DisplayName "WRCCDC_Block_RDP_3389" `
      -Direction Inbound -Action Block -Enabled True `
      -Protocol TCP -LocalPort 3389 `
      -Profile Domain,Private,Public `
      -EdgeTraversalPolicy Block | Out-Null
  } catch {}
}

Write-Host "[7/7] Done. Current profile defaults:"
try {
  Get-NetFirewallProfile |
    Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, AllowInboundRules, LogAllowed, LogBlocked, LogFileName |
    Format-Table -AutoSize
} catch {}

Write-Host ""
Write-Host "Rules created:" -ForegroundColor Green
try {
  Get-NetFirewallRule -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "WRCCDC_*" } |
    Select-Object DisplayName, Direction, Action, Enabled, Profile |
    Format-Table -AutoSize
} catch {}

Write-Host ""
Write-Host "Backup saved at: $backupPath" -ForegroundColor Yellow
Write-Host "Tip: baseline AD ports are always applied. Rerun and add extras at the prompt if a scored service breaks." -ForegroundColor Yellow
