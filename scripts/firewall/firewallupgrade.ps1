# WRCCDC_Firewall_Baseline.ps1

param(
  [switch]$ActiveProfilesOnly 
)

# ================== EDIT THESE ==================
$AllowedInboundTCP = @(21)   
$AllowedInboundUDP = @()          
$EnableRDP = $true                 
$RestrictRDP = $true
$RdpAllowedRemoteAddresses = @(
  "10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"
) 
$LogFolder = "$env:SystemRoot\System32\LogFiles\Firewall"


$KeepExistingInboundRules = $true

# =================================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
  Write-Host "ERROR: Run PowerShell as Administrator." -ForegroundColor Red
  exit 1
}

Write-Host "=== WRCCDC Firewall Baseline ===" -ForegroundColor Cyan

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
$backupPath = "C:\fwbackup_$ts.wfw"
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

Write-Host "[5/7] Creating inbound allow rules for required services"

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
Write-Host "Tip: If scoring breaks, add the needed port to AllowedInboundTCP and rerun." -ForegroundColor Yellow
