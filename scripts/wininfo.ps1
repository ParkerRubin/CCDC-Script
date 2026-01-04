# wininfo.ps1 - readable inventory + evidence
$hostname  = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"

$outDir  = Join-Path (Get-Location) "Inventory_${hostname}_${timestamp}"
$outFile = Join-Path $outDir "inventory.txt"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Add($line="") { $line | Out-File -FilePath $outFile -Append -Encoding utf8 }

# Collect OS + IPs
$os = Get-CimInstance Win32_OperatingSystem
$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike "169.254*" -and $_.IPAddress -ne "127.0.0.1" } |
  Sort-Object InterfaceAlias,IPAddress

# Listening ports with PID
$tcpListen = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Select-Object LocalPort, OwningProcess)
$udpListen = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue |
  Select-Object LocalPort, OwningProcess)

# Build unified list
$listen = @()
foreach ($t in $tcpListen) { $listen += [pscustomobject]@{ Proto="tcp"; Port=[int]$t.LocalPort; PID=[int]$t.OwningProcess } }
foreach ($u in $udpListen) { $listen += [pscustomobject]@{ Proto="udp"; Port=[int]$u.LocalPort; PID=[int]$u.OwningProcess } }
$listen = $listen | Sort-Object Proto,Port,PID -Unique

# PID -> process
$procMap = @{}
Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $procMap[$_.Id] = $_.ProcessName }

# PID -> service(s)
$svcByPid = @{}
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | ForEach-Object {
  if ($_.ProcessId -and $_.ProcessId -ne 0) {
    if (-not $svcByPid.ContainsKey($_.ProcessId)) { $svcByPid[$_.ProcessId] = @() }
    $svcByPid[$_.ProcessId] += $_.Name
  }
}

# Port -> friendly service labels (match your friend's vibe)
$portMap = @{
  22   = "Remote (ssh)"
  80   = "HTTP"
  443  = "HTTPS"
  3389 = "Remote (rdp)"
  445  = "File Share (smb)"
  135  = "RPC"
  53   = "DNS"
  389  = "LDAP"
  636  = "LDAPS"
  88   = "Kerberos"
  1433 = "Database (mssql)"
  3306 = "Database (mysql)"
  5432 = "Database (postgres)"
  25   = "Mail (smtp)"
  110  = "Mail (pop3)"
  143  = "Mail (imap)"
  587  = "Mail (submission)"
  5985 = "Remote (winrm)"
  5986 = "Remote (winrm-https)"
}

# Services list for "Services:" line (dedup)
$serviceLabels = New-Object System.Collections.Generic.HashSet[string]
foreach ($row in $listen) {
  if ($portMap.ContainsKey($row.Port)) {
    [void]$serviceLabels.Add($portMap[$row.Port])
  }
}

# Header
Add "Inventory Report"
Add ("Generated: {0}" -f (Get-Date))
Add ""

Add "Host:"
Add ("  {0}" -f $hostname)
Add ""

Add "Operating System:"
Add ("  {0} (Version {1}, Build {2})" -f $os.Caption, $os.Version, $os.BuildNumber)
Add ""

Add "IP Addresses (IPv4):"
if ($ips) {
  foreach ($ip in $ips) { Add ("  {0}: {1}" -f $ip.InterfaceAlias, $ip.IPAddress) }
} else {
  Add "  (none found)"
}
Add ""

# Readable services line (friend-style)
Add "Services (inferred from listening ports):"
if ($serviceLabels.Count -gt 0) {
  $svcLine = ($serviceLabels | Sort-Object) -join ", "
  Add ("  {0}" -f $svcLine)
} else {
  Add "  (none mapped — only unmapped/ephemeral ports detected)"
}
Add ""

# Optional: show which ports caused those service labels
Add "Required Ports (mapped):"
$mappedRows = $listen | Where-Object { $portMap.ContainsKey($_.Port) } | Sort-Object Port,Proto -Unique
if ($mappedRows) {
  foreach ($m in $mappedRows) {
    Add ("  {0,5}/{1}  -> {2}" -f $m.Port, $m.Proto, $portMap[$m.Port])
  }
} else {
  Add "  (none)"
}
Add ""

# Evidence section (this is what makes you score well)
Add "Evidence (Listening Port -> Process -> Windows Service):"
if ($listen.Count -eq 0) {
  Add "  (none)"
} else {
  foreach ($row in ($listen | Sort-Object Port,Proto,PID)) {
    $pname = $(if ($procMap.ContainsKey($row.PID)) { $procMap[$row.PID] } else { "UNKNOWN" })
    $svcs  = $(if ($svcByPid.ContainsKey($row.PID)) { ($svcByPid[$row.PID] | Sort-Object -Unique) -join "," } else { "" })

    if ([string]::IsNullOrWhiteSpace($svcs)) {
      Add ("  {0,5}/{1,-3}  PID:{2,-6}  Proc:{3}" -f $row.Port, $row.Proto, $row.PID, $pname)
    } else {
      Add ("  {0,5}/{1,-3}  PID:{2,-6}  Proc:{3,-18}  Svc:{4}" -f $row.Port, $row.Proto, $row.PID, $pname, $svcs)
    }
  }
}
Add ""

# Containers quick check
Add "Containers:"
if (Get-Command docker -ErrorAction SilentlyContinue) {
  Add "  Docker detected:"
  docker ps -a --format "  {{.Names}} | {{.Image}} | {{.Status}} | {{.Ports}}" 2>$null |
    Out-File $outFile -Append -Encoding utf8
} else {
  Add "  Docker not installed."
}
Add ""
Add ("Saved to: {0}" -f $outFile)

Write-Host "Saved: $outFile"
