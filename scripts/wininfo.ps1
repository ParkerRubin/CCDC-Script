# wininfo.ps1
# Inventory report in current directory:
# Hostname, OS, IPs, mapped services/ports, plus listening ports with owning process and Windows service.

$hostname  = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"

$outDir  = Join-Path (Get-Location) "Inventory_${hostname}_${timestamp}"
$outFile = Join-Path $outDir "inventory.txt"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Add($line="") { $line | Out-File -FilePath $outFile -Append -Encoding utf8 }

# Header
Add "Inventory Report"
Add ("Generated: {0}" -f (Get-Date))
Add ""

# Host / OS
$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem

Add "Hostnames:"
Add ("  {0}" -f $hostname)
Add ""

Add "Operating System:"
Add ("  {0} (Version {1}, Build {2})" -f $os.Caption, $os.Version, $os.BuildNumber)
Add ""

# IPs
Add "IP Addresses (IPv4):"
$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike "169.254*" -and $_.IPAddress -ne "127.0.0.1" } |
    Sort-Object InterfaceAlias,IPAddress

if ($ips) {
    foreach ($ip in $ips) { Add ("  {0}: {1}" -f $ip.InterfaceAlias, $ip.IPAddress) }
} else {
    Add "  (none found)"
}
Add ""

# Collect listening ports with owner PID
$tcpListen = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Select-Object LocalAddress, LocalPort, OwningProcess)
$udpListen = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue |
    Select-Object LocalAddress, LocalPort, OwningProcess)

# Build PID->ProcessName map
$procMap = @{}
Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $procMap[$_.Id] = $_.ProcessName }

# Build PID->ServiceName(s) map using CIM (svchost can host many)
$svcByPid = @{}
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.ProcessId -and $_.ProcessId -ne 0) {
        if (-not $svcByPid.ContainsKey($_.ProcessId)) { $svcByPid[$_.ProcessId] = @() }
        $svcByPid[$_.ProcessId] += $_.Name
    }
}

# Port → friendly service mapping (common “role hint” ports)
$portMap = @{
    22   = "Remote (SSH)"
    53   = "DNS"
    80   = "Web (HTTP)"
    88   = "Kerberos"
    110  = "POP3"
    123  = "NTP"
    135  = "RPC Endpoint Mapper"
    137  = "NetBIOS Name"
    138  = "NetBIOS Datagram"
    139  = "NetBIOS Session"
    143  = "IMAP"
    389  = "LDAP"
    443  = "Web (HTTPS)"
    445  = "SMB"
    464  = "Kerberos Password"
    587  = "SMTP (Submission)"
    636  = "LDAPS"
    1433 = "MS SQL"
    3306 = "MySQL/MariaDB"
    3389 = "Remote Desktop (RDP)"
    5432 = "PostgreSQL"
    5985 = "WinRM (HTTP)"
    5986 = "WinRM (HTTPS)"
    8080 = "Web (HTTP-alt)"
    8443 = "Web (HTTPS-alt)"
}

# Create unified list (proto, port, pid)
$listen = @()
foreach ($t in $tcpListen) { $listen += [pscustomobject]@{ Proto="tcp"; Port=[int]$t.LocalPort; PID=[int]$t.OwningProcess } }
foreach ($u in $udpListen) { $listen += [pscustomobject]@{ Proto="udp"; Port=[int]$u.LocalPort; PID=[int]$u.OwningProcess } }
$listen = $listen | Sort-Object Proto,Port,PID -Unique

# Mapped Services summary
Add "Services / Required Ports (listening on this host):"
$found = @{}
foreach ($row in $listen) {
    if ($portMap.ContainsKey($row.Port)) {
        $svc = $portMap[$row.Port]
        if (-not $found.ContainsKey($svc)) { $found[$svc] = @() }
        $found[$svc] += ("{0}/{1}" -f $row.Port, $row.Proto)
    }
}
if ($found.Keys.Count -eq 0) {
    Add "  (No mapped services detected from listening ports)"
} else {
    foreach ($svc in ($found.Keys | Sort-Object)) {
        $ports = ($found[$svc] | Sort-Object -Unique) -join ", "
        Add ("  {0}: {1}" -f $svc, $ports)
    }
}
Add ""

# Unmapped ports (like your example)
Add "Other Listening Ports (unmapped):"
$unmapped = $listen | Where-Object { -not $portMap.ContainsKey($_.Port) }
if ($unmapped) {
    foreach ($u in $unmapped) { Add ("  {0}/{1}" -f $u.Port, $u.Proto) }
} else {
    Add "  (none)"
}
Add ""

# NEW: Actionable detail section (port -> process -> service(s))
Add "Listening Ports with Owner (Actionable):"
if ($listen.Count -eq 0) {
    Add "  (none)"
} else {
    foreach ($row in $listen) {
        $pname = $(if ($procMap.ContainsKey($row.PID)) { $procMap[$row.PID] } else { "UNKNOWN" })
        $svcs  = $(if ($svcByPid.ContainsKey($row.PID)) { ($svcByPid[$row.PID] | Sort-Object -Unique) -join "," } else { "" })

        if ([string]::IsNullOrWhiteSpace($svcs)) {
            Add ("  {0,6}/{1,-3}  PID:{2,-6}  Proc:{3}" -f $row.Port, $row.Proto, $row.PID, $pname)
        } else {
            Add ("  {0,6}/{1,-3}  PID:{2,-6}  Proc:{3,-18}  Svc:{4}" -f $row.Port, $row.Proto, $row.PID, $pname, $svcs)
        }
    }
}
Add ""

# Containers
Add "Containers (Docker):"
if (Get-Command docker -ErrorAction SilentlyContinue) {
    docker ps -a --format "  {{.Names}} | {{.Image}} | {{.Status}} | {{.Ports}}" 2>$null |
        Out-File $outFile -Append -Encoding utf8
} else {
    Add "  Docker not installed."
}
Add ""
Add ("Saved to: {0}" -f $outFile)

Write-Host "Saved: $outFile"
