#triage_full.ps1

param(
  [string]$BaseDir = "C:\WRCCDC",
  [int]$LookbackHours = 12,
  [switch]$ContainmentMode
)

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

function Write-ErrorFile {
  param([string]$CaseDir,[string]$Name,[string]$Message)
  "$Name failed: $Message" | Out-File -FilePath (Join-Path $CaseDir "$Name`_error.txt") -Encoding UTF8 -Force
}

function Try-Run {
  param([string]$Cmd,[string]$OutPath)
  try {
    $o = cmd.exe /c $Cmd 2>&1
    $o | Out-File -FilePath $OutPath -Encoding UTF8
  } catch {
    "$Cmd failed: $($_.Exception.Message)" | Out-File -FilePath $OutPath -Encoding UTF8
  }
}

function Get-AdminMembers {
  try {
    return Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop |
      Select-Object Name, ObjectClass, PrincipalSource
  } catch { return @() }
}

function Get-LocalUsersSafe {
  try { return Get-LocalUser -ErrorAction Stop | Select-Object Name, Enabled, LastLogon } catch { return @() }
}

# Hints for living-off-the-land binaries commonly abused in post-exploitation.
# Presence alone is NOT proof of compromise - most of these run legitimately
# on any Windows box. The command line captured alongside each hit is what
# actually distinguishes normal usage from suspicious usage.
function Suspicious-ProcessHints {
  $hints = @(
    "powershell","cmd","wscript","cscript","rundll32","regsvr32","mshta","wmic",
    "bitsadmin","certutil","psexec","schtasks","nltest"
  )

  try {
    Get-CimInstance Win32_Process -ErrorAction Stop |
      Select-Object Name, ProcessId, ParentProcessId, CommandLine,
        @{n="Path";e={$_.ExecutablePath}} |
      Where-Object {
        $n = ($_.Name + "").ToLower()
        ($hints | Where-Object { $n -like "*$_*" } | Select-Object -First 1) -ne $null
      } |
      Select-Object -First 200
  } catch {
    return @()
  }
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

if (($admins | Measure-Object).Count -eq 0) {
  Write-ErrorFile -CaseDir $CaseDir -Name "admins" -Message "query failed or returned no results"
} else {
  $admins | Format-Table -AutoSize | Out-String | Out-File (Join-Path $CaseDir "admins.txt") -Encoding UTF8
}

if (($users | Measure-Object).Count -eq 0) {
  Write-ErrorFile -CaseDir $CaseDir -Name "local_users" -Message "query failed or returned no results"
} else {
  $users | Format-Table -AutoSize | Out-String | Out-File (Join-Path $CaseDir "local_users.txt") -Encoding UTF8
}

$adminLines = @()
foreach ($a in $admins) { $adminLines += "$($a.Name) [$($a.ObjectClass)]" }
if ($adminLines.Count -eq 0) { $adminLines = @("Could not query or none found.") }
Write-Section -Path $SummaryPath -Title "Admins (quick view)" -Lines $adminLines

# --- Services (running + autostart) ---
try {
  Get-Service -ErrorAction Stop |
    Where-Object { $_.StartType -in @("Automatic","AutomaticDelayedStart") } |
    Sort-Object Status, Name |
    Select-Object Status, StartType, Name, DisplayName |
    Out-File (Join-Path $CaseDir "services_autostart.txt") -Encoding UTF8
} catch {
  Write-ErrorFile -CaseDir $CaseDir -Name "services_autostart" -Message $_.Exception.Message
}

try {
  Get-Service -ErrorAction Stop | Where-Object {$_.Status -eq "Running"} |
    Select-Object Status, StartType, Name, DisplayName |
    Out-File (Join-Path $CaseDir "services_running.txt") -Encoding UTF8
} catch {
  Write-ErrorFile -CaseDir $CaseDir -Name "services_running" -Message $_.Exception.Message
}

# --- Scheduled Tasks (non-Microsoft) ---
try {
  $tasks = Get-ScheduledTask -ErrorAction Stop | Select-Object TaskName, TaskPath, State
  $tasks | Out-File (Join-Path $CaseDir "tasks_all.txt") -Encoding UTF8

  $nonMs = $tasks | Where-Object { $_.TaskPath -notlike "\Microsoft\*" }
  $nonMs | Out-File (Join-Path $CaseDir "tasks_non_microsoft.txt") -Encoding UTF8

  $taskLines = @()
  foreach ($t in $nonMs) { $taskLines += "$($t.TaskPath)$($t.TaskName) [$($t.State)]" }
  if ($taskLines.Count -eq 0) { $taskLines = @("None found (or query failed).") }

  Write-Section -Path $SummaryPath -Title "Non-Microsoft scheduled tasks (quick view)" -Lines $taskLines
} catch {
  Write-ErrorFile -CaseDir $CaseDir -Name "tasks" -Message $_.Exception.Message
}

# --- Network: ports, config, routes, shares ---
Try-Run -Cmd "netstat -ano"   -OutPath (Join-Path $CaseDir "netstat_ano.txt")
Try-Run -Cmd "ipconfig /all"  -OutPath (Join-Path $CaseDir "ipconfig_all.txt")
Try-Run -Cmd "arp -a"         -OutPath (Join-Path $CaseDir "arp_a.txt")
Try-Run -Cmd "route print"    -OutPath (Join-Path $CaseDir "route_print.txt")
Try-Run -Cmd "net share"      -OutPath (Join-Path $CaseDir "shares.txt")

# Firewall profiles
try {
  Get-NetFirewallProfile -ErrorAction Stop |
    Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction |
    Sort-Object Name |
    Format-Table -AutoSize | Out-String |
    Out-File (Join-Path $CaseDir "firewall_profiles.txt") -Encoding UTF8
} catch {
  Write-ErrorFile -CaseDir $CaseDir -Name "firewall_profiles" -Message $_.Exception.Message
}

# --- Processes: hints (with command line) + PID map ---
$susp = Suspicious-ProcessHints
if (($susp | Measure-Object).Count -eq 0) {
  Write-ErrorFile -CaseDir $CaseDir -Name "process_hints" -Message "query failed or returned no results"
} else {
  $susp | Format-Table -AutoSize -Wrap | Out-String | Out-File (Join-Path $CaseDir "process_hints.txt") -Encoding UTF8
}

try {
  Get-Process -ErrorAction Stop |
    Select-Object Name, Id, Path |
    Sort-Object Id |
    Out-File (Join-Path $CaseDir "process_pid_map.txt") -Encoding UTF8
} catch {
  Write-ErrorFile -CaseDir $CaseDir -Name "process_pid_map" -Message $_.Exception.Message
}

# CPU-sorted view - surfaces runaway/heavy processes (e.g. miners, brute
# forcers) that a PID-ordered list won't make obvious.
try {
  Get-Process -ErrorAction Stop |
    Sort-Object CPU -Descending |
    Select-Object -First 200 Name, Id, CPU,
      @{Name="WorkingSetMB";Expression={[math]::Round($_.WorkingSet64/1MB,1)}},
      Path |
    Format-Table -AutoSize | Out-String -Width 260 |
    Out-File (Join-Path $CaseDir "process_by_cpu.txt") -Encoding UTF8
} catch {
  Write-ErrorFile -CaseDir $CaseDir -Name "process_by_cpu" -Message $_.Exception.Message
}

$procLines = @()
if (($susp | Measure-Object).Count -eq 0) {
  $procLines = @("None flagged by simple hint list.")
} else {
  foreach ($p in ($susp | Select-Object -First 20)) {
    $cmdShort = if ($p.CommandLine) { $p.CommandLine } else { "(no command line captured)" }
    $procLines += "$($p.Name) (PID $($p.ProcessId), Parent $($p.ParentProcessId)) Cmd=$cmdShort"
  }
}
Write-Section -Path $SummaryPath -Title "Process hints (quick view - review command lines, not just names)" -Lines $procLines

# --- Event logs ---
$since = (Get-Date).AddHours(-1 * $LookbackHours)

try {
  Get-WinEvent -FilterHashtable @{LogName="System"; StartTime=$since} -MaxEvents 300 -ErrorAction Stop |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
    Out-File (Join-Path $CaseDir "event_system_last${LookbackHours}h.txt") -Encoding UTF8
} catch {
  Write-ErrorFile -CaseDir $CaseDir -Name "event_system" -Message $_.Exception.Message
}

try {
  Get-WinEvent -FilterHashtable @{LogName="Application"; StartTime=$since} -MaxEvents 300 -ErrorAction Stop |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
    Out-File (Join-Path $CaseDir "event_application_last${LookbackHours}h.txt") -Encoding UTF8
} catch {
  Write-ErrorFile -CaseDir $CaseDir -Name "event_application" -Message $_.Exception.Message
}

try {
  Get-WinEvent -FilterHashtable @{LogName="Security"; StartTime=$since} -MaxEvents 300 -ErrorAction Stop |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
    Out-File (Join-Path $CaseDir "event_security_last${LookbackHours}h.txt") -Encoding UTF8
} catch {
  # Security log commonly fails here for permission reasons distinct from
  # plain Administrator rights (audit policy / SACL access). An empty
  # result above this catch does NOT necessarily mean "no events" - check
  # this error file before assuming a quiet Security log is a clean one.
  Write-ErrorFile -CaseDir $CaseDir -Name "event_security" -Message $_.Exception.Message
}

# Targeted Security event IDs - logon success/fail, account creation/
# modification, admin group membership changes. Unlike the lookback-window
# pull above, this isn't time-bounded, so it catches relevant events even
# if they happened outside LookbackHours. Narrower signal, less noise than
# scanning all Security events.
try {
  Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=4624,4625,4720,4722,4723,4724,4725,4726,4732,4733 } -MaxEvents 200 -ErrorAction Stop |
    Select-Object TimeCreated, Id, ProviderName, Message |
    Format-List | Out-String |
    Out-File (Join-Path $CaseDir "event_security_targeted.txt") -Encoding UTF8
} catch {
  # Same Security-log elevation caveat applies here as the lookback pull.
  Write-ErrorFile -CaseDir $CaseDir -Name "event_security_targeted" -Message $_.Exception.Message
}

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
# NOTE: this currently performs ONE narrow action - disabling running
# non-Microsoft scheduled tasks. It does not isolate the network, kill
# processes, or lock accounts. Treat it as a single containment step,
# not full incident containment.
if ($ContainmentMode) {
  Add-Content -Path $SummaryPath -Value ""
  Add-Content -Path $SummaryPath -Value "==== CONTAINMENT ACTIONS TAKEN: disable non-Microsoft running scheduled tasks ===="

  try {
    $nonMsRunning = Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -notlike "\Microsoft\*" -and $_.State -eq "Running" }
    foreach ($t in $nonMsRunning) {
      $full = "$($t.TaskPath)$($t.TaskName)"
      Add-Content -Path $SummaryPath -Value "Disabling scheduled task: $full"
      Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop | Out-Null
    }
    if (($nonMsRunning | Measure-Object).Count -eq 0) {
      Add-Content -Path $SummaryPath -Value "No non-Microsoft running scheduled tasks to disable."
    }
  } catch {
    Add-Content -Path $SummaryPath -Value "Containment tasks: failed to enumerate/disable - $($_.Exception.Message)"
  }
}

Add-Content -Path $SummaryPath -Value ""
Add-Content -Path $SummaryPath -Value "Done. Review SUMMARY.txt first, then dig into the dump files."
Add-Content -Path $SummaryPath -Value "event_security_targeted.txt narrows to logon, account-change, and admin-group-membership event IDs - check it alongside the full event_security_lastXXh.txt dump."
Add-Content -Path $SummaryPath -Value "process_by_cpu.txt sorts by CPU usage - check it for anything unexpectedly heavy (miners, brute-force loops)."
Add-Content -Path $SummaryPath -Value "Any *_error.txt files in this folder indicate a section failed to collect - check those before assuming a quiet result means 'nothing found'."

Write-Host "Triage complete."
Write-Host "Case folder: $CaseDir"
Write-Host "Summary: $SummaryPath"
