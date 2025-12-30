<#
05_watch_triage.ps1
WRCCDC Windows Triage + Light Automation (SAFE by default)

Usage:
  # one-time triage run (safe)
  powershell -ExecutionPolicy Bypass -File .\05_watch_triage.ps1

  # run and store in a custom folder
  powershell -ExecutionPolicy Bypass -File .\05_watch_triage.ps1 -BaseDir "C:\IR"

  # enable containment (NOT recommended unless you know what you’re doing)
  powershell -ExecutionPolicy Bypass -File .\05_watch_triage.ps1 -ContainmentMode

What it does:
- Dumps key security/host state to timestamped folder
- Flags suspicious items
- Does NOT kill/disable anything unless -ContainmentMode is set
#>

param(
  [string]$BaseDir = "C:\WRCCDC",
  [switch]$ContainmentMode
)

$ErrorActionPreference = "SilentlyContinue"

function New-CaseFolder {
  param([string]$Root)
  if (!(Test-Path $Root)) { New-Item -ItemType Directory -Path $Root | Out-Null }
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $case = Join-Path $Root "triage_$stamp"
  New-Item -ItemType Directory -Path $case | Out-Null
  return $case
}

function Write-Section {
  param([string]$Path,[string]$Title,[string[]]$Lines)
  Add-Content -Path $Path -Value ""
  Add-Content -Path $Path -Value ("==== " + $Title + " ====")
  $Lines | ForEach-Object { Add-Content -Path $Path -Value $_ }
}

function Save-Text {
  param([string]$Path,[string]$Content)
  $Content | Out-File -FilePath $Path -Encoding UTF8
}

function Try-Run {
  param([string]$Cmd,[string]$OutPath)
  $o = cmd.exe /c $Cmd 2>&1
  $o | Out-File -FilePath $OutPath -Encoding UTF8
}

function Get-AdminMembers {
  try {
    $admins = Get-LocalGroupMember -Group "Administrators" | Select-Object Name, ObjectClass, PrincipalSource
    return $admins
  } catch {
    return @()
  }
}

function Get-LocalUsersSafe {
  try { return Get-LocalUser | Select-Object Name, Enabled, LastLogon } catch { return @() }
}

function Suspicious-ProcessHints {
  $hints = @("powershell","cmd","wscript","cscript","rundll32","regsvr32","mshta","wmic","bitsadmin","certutil","psexec","schtasks","net","nltest")
  $procs = Get-Process | Select-Object Name, Id, Path -ErrorAction SilentlyContinue
  $flag = $procs | Where-Object {
    $n = $_.Name.ToLower()
    $hints | ForEach-Object { if ($n -like "*$_*") { return $true } }
    return $false
  } | Select-Object -First 200
  return $flag
}

# --- Create case folder + summary file ---
$CaseDir = New-CaseFolder -Root $BaseDir
$SummaryPath = Join-Path $CaseDir "SUMMARY.txt"

Save-Text -Path $SummaryPath -Content @"
WRCCDC TRIAGE SUMMARY
Time: $(Get-Date)
Host: $env:COMPUTERNAME
User: $env:USERNAME
ContainmentMode: $ContainmentMode
CaseDir: $CaseDir
"@

# --- 1) Users + Admins ---
$admins = Get-AdminMembers
$users  = Get-LocalUsersSafe

$admins | Format-Table -AutoSize | Out-String | Out-File (Join-Path $CaseDir "admins.txt") -Encoding UTF8
$users  | Format-Table -AutoSize | Out-String | Out-File (Join-Path $CaseDir "local_users.txt") -Encoding UTF8

Write-Section -Path $SummaryPath -Title "Admins (quick view)" -Lines ($admins | ForEach-Object { "$($_.Name) [$($_.ObjectClass)]" })

# --- 2) Services (running + auto-start) ---
Get-Service | Sort-Object Status, Name |
  Select-Object Status, StartType, Name, DisplayName |
  Out-File (Join-Path $CaseDir "services_all.txt") -Encoding UTF8

Get-Service | Where-Object {$_.Status -eq "Running"} |
  Select-Object Status, StartType, Name, DisplayName |
  Out-File (Join-Path $CaseDir "services_running.txt") -Encoding UTF8

# --- 3) Scheduled Tasks (non-Microsoft focus) ---
try {
  $tasks = Get-ScheduledTask | Select-Object TaskName, TaskPath, State
  $tasks | Out-File (Join-Path $CaseDir "tasks_all.txt") -Encoding UTF8

  $nonMs = $tasks | Where-Object { $_.TaskPath -notlike "\Microsoft\*" }
  $nonMs | Out-File (Join-Path $CaseDir "tasks_non_microsoft.txt") -Encoding UTF8

  Write-Section -Path $SummaryPath -Title "Non-Microsoft scheduled tasks (quick view)" -Lines ($nonMs | ForEach-Object { "$($_.TaskPath)$($_.TaskName) [$($_.State)]" })
} catch {}

# --- 4) Network: listening ports + connections ---
Try-Run -Cmd "netstat -ano" -OutPath (Join-Path $CaseDir "netstat_ano.txt")
Try-Run -Cmd "ipconfig /all" -OutPath (Join-Path $CaseDir "ipconfig_all.txt")
Try-Run -Cmd "arp -a" -OutPath (Join-Path $CaseDir "arp_a.txt")
Try-Run -Cmd "route print" -OutPath (Join-Path $CaseDir "route_print.txt")

# --- 5) Processes: suspicious hints (NOT proof, just triage) ---
$susp = Suspicious-ProcessHints
$susp | Format-Table -AutoSize | Out-String | Out-File (Join-Path $CaseDir "process_suspicious_hints.txt") -Encoding UTF8

Write-Section -Path $SummaryPath -Title "Process hints (quick view)" -Lines (
  if ($susp.Count -eq 0) { "None flagged by simple hint list." }
  else { $susp | Select-Object -First 20 | ForEach-Object { "$($_.Name) (PID $($_.Id)) Path=$($_.Path)" } }
)

# --- 6) Event logs (recent) ---
# Security log may require admin; if it fails you still get System + Application.
$since = (Get-Date).AddHours(-12)

try {
  Get-WinEvent -FilterHashtable @{LogName="System"; StartTime=$since} -MaxEvents 300 |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
    Out-File (Join-Path $CaseDir "event_system_last12h.txt") -Encoding UTF8
} catch {}

try {
  Get-WinEvent -FilterHashtable @{LogName="Application"; StartTime=$since} -MaxEvents 300 |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
    Out-File (Join-Path $CaseDir "event_application_last12h.txt") -Encoding UTF8
} catch {}

try {
  Get-WinEvent -FilterHashtable @{LogName="Security"; StartTime=$since} -MaxEvents 300 |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
    Out-File (Join-Path $CaseDir "event_security_last12h.txt") -Encoding UTF8
} catch {}

# --- 7) Light “automation”: highlight account risk ---
$enabledUsers = @()
try { $enabledUsers = $users | Where-Object {$_.Enabled -eq $true} } catch {}
Write-Section -Path $SummaryPath -Title "Enabled local users (quick view)" -Lines (
  if ($enabledUsers.Count -eq 0) { "Could not query or none found." }
  else { $enabledUsers | ForEach-Object { "$($_.Name) LastLogon=$($_.LastLogon)" } }
)

# --- OPTIONAL Containment Mode (OFF by default) ---
# This is intentionally conservative and only targets obvious non-MS scheduled tasks that are running.
if ($ContainmentMode) {
  Add-Content -Path $SummaryPath -Value ""
  Add-Content -Path $SummaryPath -Value "==== CONTAINMENT ACTIONS (enabled) ===="

  try {
    $nonMsRunning = Get-ScheduledTask | Where-Object { $_.TaskPath -notlike "\Microsoft\*" -and $_.State -eq "Running" }
    foreach ($t in $nonMsRunning) {
      $full = "$($t.TaskPath)$($t.TaskName)"
      Add-Content -Path $SummaryPath -Value "Disabling scheduled task: $full"
      Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath | Out-Null
    }
    if ($nonMsRunning.Count -eq 0) {
      Add-Content -Path $SummaryPath -Value "No non-Microsoft running scheduled tasks to disable."
    }
  } catch {
    Add-Content -Path $SummaryPath -Value "Containment tasks: failed to enumerate/disable."
  }
}

Add-Content -Path $SummaryPath -Value ""
Add-Content -Path $SummaryPath -Value "Done. Review SUMMARY.txt first, then dig into the dump files."

Write-Host "Triage complete."
Write-Host "Case folder: $CaseDir"
Write-Host "Summary: $SummaryPath"
