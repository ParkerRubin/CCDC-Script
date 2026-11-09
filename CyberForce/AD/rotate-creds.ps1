# ============================================================
# CYBERFORCE 2026 - ROTATE CREDS - AD (Windows Server 2022, Domain Controller)
# blueteam:BlueTeam2026! is PUBLIC in the comp repo - likely exists
# BOTH as a domain account AND local (DC usually shares local admin).
# NEVER rotate: SCORE1/SCORE2/PATCH (scoring SSH), and be careful -
# this is a DC: rotating DOMAIN accounts locks out teammates until
# updated. Rotate domain accounts ONLY with full-team knowledge.
# Default behavior = LOCAL accounts only (safe) + full AD user audit.
# ============================================================
param(
  [string]$User = "blueteam",
  [string]$RotateToo = "",       # extra LOCAL users, comma-separated
  [switch]$IncludeDomain         # also rotate DOMAIN matches (advanced - full team must know)
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "ERROR: Run PowerShell as Administrator." -ForegroundColor Red; exit 1 }

$Protected = @('SCORE1','SCORE2','PATCH')
$Dir = "C:\CF-Toolkit\Creds"
$TS  = Get-Date -Format "yyyyMMdd-HHmmss"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Out = Join-Path $Dir "cred-sheet-ad-$TS.txt"

function New-Password {
  $c = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'
  $p = -join (1..22 | ForEach-Object { $c[(Get-Random -Maximum $c.Length)] })
  "$p`#Pa1"
}

Add-Content $Out "== CF rotate-creds -- AD -- $TS =="

# ---- 1. local users ----
Add-Content $Out "`n-- LOCAL users --"
Get-LocalUser | ForEach-Object {
  Add-Content $Out ("  {0,-20} Enabled={1,-6} PwdRequired={2}" -f $_.Name, $_.Enabled, $_.PasswordRequired)
}
Add-Content $Out "`n-- Administrators group (local) --"
Get-LocalGroupMember Administrators | ForEach-Object { Add-Content $Out "  $($_.Name)" }

# ---- 2. AD domain user audit (read-only) ----
Add-Content $Out "`n-- DOMAIN users (audit, via AD module) --"
if (Get-Command Get-ADUser -ErrorAction SilentlyContinue) {
  Get-ADUser -Filter * -Properties Enabled, PasswordLastSet, LastLogonDate, PasswordNeverExpires |
    ForEach-Object {
      Add-Content $Out ("  {0,-24} Enabled={1,-6} PwdLastSet={2}" -f $_.SamAccountName, $_.Enabled, $_.PasswordLastSet)
      if ($_.PasswordLastSet -eq $null) { Add-Content $Out "    ** NEVER SET PASSWORD - audit this account" }
    }
  Add-Content $Out "`n-- Domain Admins / Admin groups (flag unexpected members) --"
  foreach ($g in @('Domain Admins','Administrators','Enterprise Admins')) {
    try {
      Get-ADGroupMember (Get-ADGroup $g -ErrorAction Stop) -ErrorAction Stop |
        ForEach-Object { Add-Content $Out "  [$g] $($_.SamAccountName)" }
    } catch { Add-Content $Out "  [$g] (not readable - fine on lesser perms)" }
  }
} else {
  Add-Content $Out "  (AD module absent - run on a workstation that has RSAT or via RSAT session)"
}

# ---- 3. rotate LOCAL accounts ----
foreach ($u in (@($User) + ($RotateToo -split ',' | Where-Object { $_ }))) {
  if ($Protected -contains $u) { Write-Host "SKIP protected account: $u" -ForegroundColor Red; continue }
  if (-not (Get-LocalUser -Name $u -ErrorAction SilentlyContinue)) { Write-Host "No such local user: $u" -ForegroundColor DarkGray; continue }
  $pw = New-Password
  Set-LocalUser -Name $u -Password (ConvertTo-SecureString $pw -AsPlainText -Force)
  Add-Content $Out "ROTATED  local $u -> $pw"
  Write-Host "ROTATED  local $u" -ForegroundColor Green
}

# ---- 4. optional: rotate DIFFERENT domain accounts w/ explicit names only ----
if ($IncludeDomain) {
  Write-Host ""
  $du = Read-Host "Domain SamAccountName to rotate (or blank=none)"
  while ($du) {
    if ($Protected -contains $du) { Write-Host "SKIP protected: $du" -ForegroundColor Red }
    else {
      $pw = New-Password
      try { Set-ADAccountPassword -Identity $du -Reset -NewPassword (ConvertTo-SecureString $pw -AsPlainText -Force) -Confirm:$false
            Add-Content $Out "ROTATED  domain $du -> $pw"; Write-Host "ROTATED domain $du" -ForegroundColor Green }
      catch { Write-Host "Failed: $du $_" -ForegroundColor Red }
    }
    $du = Read-Host "Another domain SamAccountName (blank=done)"
  }
}

# ---- 5. default-password landmines ----
Write-Host ""
Write-Host "Scanning configs/scripts for the default password..." -ForegroundColor Yellow
$hits = Get-ChildItem -Path 'C:\Program Files','C:\Program Files (x86)','C:\inetpub','C:\Users\blueteam' -Recurse -Include *.ps1,*.bat,*.config,*.ini,*.xml,*.txt -ErrorAction SilentlyContinue |
        Select-String -Pattern 'BlueTeam2026' -List -ErrorAction SilentlyContinue
if ($hits) { $hits.Path | ForEach-Object { Write-Host "  FOUND: $_" -ForegroundColor Magenta; Add-Content $Out "GREPHIT  $_" } }
else { Write-Host "  none found" }

Add-Content $Out "`n== DONE. Sheet: $Out =="
Write-Host ""
Write-Host "Sheet saved: $Out" -ForegroundColor Cyan
Write-Host "NOTE: LDAP 389 and SNMP 161 scoring passwords live in AD/SNMP agent config -"
Write-Host "      if you rotate the account the snmp agent uses, update its manager strings too."
Write-Host "Next: firewall.ps1, then snapshot.ps1 and wininfo.ps1."
