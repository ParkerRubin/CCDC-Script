#triage_full.ps1

param(
  [string]$BaseDir = "C:\WRCCDC",
  [int]$LookbackHours = 12,
  [switch]$ContainmentMode
)

$ErrorActionPreference = "SilentlyContinue"

function New-CaseFolder {
  param([string]$Root)
  if (!(Test-Path $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $case = Join-Path $Root "triage_$stamp"
  New-Item -ItemType Directory -Path $case -Force | Out-Null
  return $case
}

function Write-Section {
  param([string]$Path,[string]$Title,[string[]]$Lines)
  Add-Content -Path $Path -Value ""
  Add-Content -Path $Path -Value ("==== " + $Title + " ====")
  foreach ($l in $Lines) { Add-Content -Path $Path -Value $l }
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
    return Get-LocalGroupMember -Group "Administrators" |
      Select-Object Name, ObjectClass, PrincipalSource
  } catch { return @() }
}

function Get-LocalUsersSafe {
  try { return Get-LocalUser | Select-Object Name, Enabled, LastLogon } catch { return @() }
}

function Suspicious-ProcessHints {
  $hints = @(
    "powershell","cmd","wscript","cscript","rundll32","regsvr32","mshta","wmic",
    "bitsadmin","certutil","psexec","schtasks","nltest"
  )

  Get-Process -ErrorAction SilentlyContinue |
    Select-Object Name, Id, Path |
    Where-Object {
      $n = ($_.Name + "").ToLower()
      ($hints | Where-Object { $n -like "*$_*" } | Select-Object -First 1) -ne $null
    } |
    Select-Object -First 200
}

# --- Create case folder + summary file ---
$CaseDir = New-CaseFolder -Root $BaseDir
$SummaryPath = Join-Path $CaseDir "SUMMARY.txt"

Save-Text -Path $SummaryPath -Content @"
WRCCDC TRIAGE SUMMARY
Time: $(Get-Date)
Host: $env:COMPUTERNAME
User: $env:USERNAME
LookbackHours: $LookbackHours
ContainmentMode: $ContainmentMode
CaseDir: $CaseDir
"@

# --- Users + Admins ---
$admins = Get-AdminMembers
$users  = Get-LocalUsersSafe

$admins | Format-Table -AutoSize | Out-String | Out-File (Join-Path $CaseDir "admins.txt") -Encoding UTF8
$users  | Format-Table -AutoSize | Out-String | Out-File (Join-Path $CaseDir "local_users.txt") -Encoding UTF8

$adminLines = @()
foreach ($a in $admins) { $adminLines += "$($a.Name) [$($a.ObjectClass)]" }
if ($adminLines.Count -eq 0) { $adminLines = @("Could not query or none found.") }
Write-Section -Path $SummaryPath -Title "Admins (quick view)" -Lines $adminLines

# --- Services (running + autostart) ---
Get-Service |
  Where-Object { $_.StartType -in @("Automatic","AutomaticDelayedStart") } |
  Sort-Object Status, Name |
  Select-Object Status, StartType, Name, DisplayName |
  Out-File (Join-Path $CaseDir "services_autostart.txt") -Encoding UTF8

Get-Service | Where-Object {$_.Status -eq "Running"} |
  Select-Object Status, StartType, Name, DisplayName |
  Out-File (Join-Path $CaseDir "services_running.txt") -Encoding UTF8

# --- Scheduled Tasks (non-Microsoft) ---
try {
  $tasks = Get-ScheduledTask | Select-Object TaskName, TaskPath, State
  $tasks | Out-File (Join-Path $CaseDir "tasks_all.txt") -Encoding UTF8

  $nonMs = $tasks | Where-Object { $_.TaskPath -notlike "\Microsoft\*" }
  $nonMs | Out-File (Join-Path $CaseDir "tasks_non_microsoft.txt") -Encoding UTF8

  $taskLines = @()
  foreach ($t in $nonMs) { $taskLines += "$($t.TaskPath)$($t.TaskName) [$($t.State)]" }
  if ($taskLines.Count -eq 0) { $taskLines = @("None found (or query failed).") }

  Write-Section -Path $SummaryPath -Title "Non-Microsoft scheduled tasks (quick view)" -Lines $taskLines
} catch {}

# --- Network: ports, config, routes, shares ---
Try-Run -Cmd "netstat -ano"   -OutPath (Join-Path $CaseDir "netstat_ano.txt")
Try-Run -Cmd "ipconfig /all"  -OutPath (Join-Path $CaseDir "ipconfig_all.txt")
Try-Run -Cmd "arp -a"         -OutPath (Join-Path $CaseDir "arp_a.txt")
Try-Run -Cmd "route print"    -OutPath (Join-Path $CaseDir "route_print.txt")
Try-Run -Cmd "net share"      -OutPath (Join-Path $CaseDir "shares.txt")

# Firewall profiles 
try {
  Get-NetFirewallProfile |
    Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction |
    Sort-Object Name |
    Format-Table -AutoSize | Out-String |
    Out-File (Join-Path $CaseDir "firewall_profiles.txt") -Encoding UTF8
} catch {}

# --- Processes: + PID map ---
$susp = Suspicious-ProcessHints
$susp | Format-Table -AutoSize | Out-String | Out-File (Join-Path $CaseDir "process_hints.txt") -Encoding UTF8

try {
  Get-Process -ErrorAction SilentlyContinue |
    Select-Object Name, Id, Path |
    Sort-Object Id |
    Out-File (Join-Path $CaseDir "process_pid_map.txt") -Encoding UTF8
} catch {}

$procLines = @()
if (($susp | Measure-Object).Count -eq 0) {
  $procLines = @("None flagged by simple hint list.")
} else {
  foreach ($p in ($susp | Select-Object -First 20)) {
    $procLines += "$($p.Name) (PID $($p.Id)) Path=$($p.Path)"
  }
}
Write-Section -Path $SummaryPath -Title "Process hints (quick view)" -Lines $procLines

# --- Event logs ---
$since = (Get-Date).AddHours(-1 * $LookbackHours)

try {
  Get-WinEvent -FilterHashtable @{LogName="System"; StartTime=$since} -MaxEvents 300 |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
    Out-File (Join-Path $CaseDir "event_system_last${LookbackHours}h.txt") -Encoding UTF8
} catch {}

try {
  Get-WinEvent -FilterHashtable @{LogName="Application"; StartTime=$since} -MaxEvents 300 |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
    Out-File (Join-Path $CaseDir "event_application_last${LookbackHours}h.txt") -Encoding UTF8
} catch {}

try {
  Get-WinEvent -FilterHashtable @{LogName="Security"; StartTime=$since} -MaxEvents 300 |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
    Out-File (Join-Path $CaseDir "event_security_last${LookbackHours}h.txt") -Encoding UTF8
} catch {}

# --- Light automation: enabled local users ---
$enabledUsers = @()
try { $enabledUsers = $users | Where-Object {$_.Enabled -eq $true} } catch {}

$userLines = @()
if (($enabledUsers | Measure-Object).Count -eq 0) {
  $userLines = @("Could not query or none found.")
} else {
  foreach ($u in $enabledUsers) { $userLines += "$($u.Name) LastLogon=$($u.LastLogon)" }
}
Write-Section -Path $SummaryPath -Title "Enabled local users (quick view)" -Lines $userLines

# --- Containment Mode ---
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
    if (($nonMsRunning | Measure-Object).Count -eq 0) {
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
