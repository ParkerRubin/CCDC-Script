# wininfo.ps1
# Clean inventory summary: Hostname, OS, IPs, and "Service: ports" derived from listening ports.

$hostname  = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"

$outDir  = Join-Path (Get-Location) "Inventory_${hostname}_${timestamp}"
$outFile = Join-Path $outDir "inventory.txt"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Add($line="") { $line | Out-File -FilePath $outFile -Append -Encoding utf8 }

# --- Header / Host / OS / IPs ---
Add "Inventory Report"
Add ("Generated: {0}" -f (Get-Date))
Add ""

$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem

Add "Hostnames:"
Add ("  {0}" -f $hostname)
Add ""

Add "Operating System:"
Add ("  {0} (Version {1}, Build {2})" -f $os.Caption, $os.Version, $os.BuildNumber)
Add ""

Add "IP Addresses (IPv4):"
$ips = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254*" -and $_.IPAddress -ne "127.0.0.1" } |
    Sort-Object InterfaceAlias,IPAddress

if ($ips) {
    foreach ($ip in $ips) { Add ("  {0}: {1}" -f $ip.InterfaceAlias, $ip.IPAddress) }
} else {
    Add "  (none found)"
}
Add ""

# --- Collect listening ports ---
$tcpPorts = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort)
$udpPorts = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort)

$listen = @()
foreach ($p in $tcpPorts) { $listen += [pscustomobject]@{ Proto="TCP"; Port=[int]$p } }
foreach ($p in $udpPorts) { $listen += [pscustomobject]@{ Proto="UDP"; Port=[int]$p } }

$listen = $listen | Sort-Object Proto,Port -Unique

# --- Port → Service mapping (you can add/remove easily) ---
$portMap = @{
    22   = "Remote (SSH)"
    53   = "DNS"
    80   = "Web (HTTP)"
    88   = "Kerberos"
    111  = "RPCBind/NFS (Linux-y)"
    123  = "NTP"
    135  = "RPC Endpoint Mapper"
    137  = "NetBIOS Name"
    138  = "NetBIOS Datagram"
    139  = "NetBIOS Session"
    389  = "LDAP"
    443  = "Web (HTTPS)"
    445  = "SMB"
    464  = "Kerberos Password"
    587  = "SMTP (Submission)"
    636  = "LDAPS"
    1433 = "MS SQL"
    1521 = "Oracle DB"
    2049 = "NFS"
    3306 = "MySQL/MariaDB"
    3389 = "Remote Desktop (RDP)"
    5432 = "PostgreSQL"
    5985 = "WinRM (HTTP)"
    5986 = "WinRM (HTTPS)"
    8000 = "Web (Alt/Dev)"
    8080 = "Web (HTTP-alt)"
    8443 = "Web (HTTPS-alt)"
}

# Group listening ports into services
$servicesFound = @{}

foreach ($row in $listen) {
    $p = $row.Port
    if ($portMap.ContainsKey($p)) {
        $svc = $portMap[$p]
        if (-not $servicesFound.ContainsKey($svc)) { $servicesFound[$svc] = @() }
        $servicesFound[$svc] += ("{0}/{1}" -f $p, $row.Proto.ToLower())
    }
}

# --- Output summary like your example ---
Add "Services / Required Ports (listening on this host):"

if ($servicesFound.Keys.Count -eq 0) {
    Add "  (No mapped services detected from listening ports)"
} else {
    foreach ($svc in ($servicesFound.Keys | Sort-Object)) {
        $ports = ($servicesFound[$svc] | Sort-Object -Unique) -join ", "
        Add ("  {0}: {1}" -f $svc, $ports)
    }
}

# Optional: also include unknown listening ports (so you don’t miss stuff)
Add ""
Add "Other Listening Ports (unmapped):"
$unmapped = $listen | Where-Object { -not $portMap.ContainsKey($_.Port) }
if ($unmapped) {
    foreach ($u in $unmapped) {
        Add ("  {0}/{1}" -f $u.Port, $u.Proto.ToLower())
    }
} else {
    Add "  (none)"
}

Add ""
Add ("Saved to: {0}" -f $outFile)
Write-Host "Saved: $outFile"
