param(
    [string]$OutRoot = (Get-Location).Path
)

$hostname  = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"

$outDir  = Join-Path $OutRoot ("Inventory_{0}_{1}" -f $hostname, $timestamp)
$outFile = Join-Path $outDir "inventory.txt"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Add([string]$line = "") {
    $line | Out-File -FilePath $outFile -Append -Encoding utf8
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

# ---------------- OS + Network ----------------
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

$netCfg = @()
try {
    $netCfg = Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.IPv4Address }
} catch { $netCfg = @() }

# ---------------- Listening Ports (single pass) ----------------
$tcp = @()
$udp = @()

try {
    $tcp = Get-NetTCPConnection -State Listen -ErrorAction Stop |
        Select-Object @{n="Proto";e={"tcp"}}, @{n="Port";e={[int]$_.LocalPort}}, @{n="ProcId";e={[int]$_.OwningProcess}}
} catch { $tcp = @() }

try {
    $udp = Get-NetUDPEndpoint -ErrorAction Stop |
        Select-Object @{n="Proto";e={"udp"}}, @{n="Port";e={[int]$_.LocalPort}}, @{n="ProcId";e={[int]$_.OwningProcess}}
} catch { $udp = @() }

$listen = @($tcp + $udp) |
    Where-Object { $_.Port -and $_.ProcId -ge 0 } |
    Sort-Object Proto, Port, ProcId -Unique

# ---------------- Process Map ----------------
$procMap = @{}
Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
    $procMap[[int]$_.Id] = $_.ProcessName
}

# ---------------- Service Map (PID -> service names) ----------------
$svcByProcId = @{}
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessId -gt 0 } |
    ForEach-Object {
        $procId = [int]$_.ProcessId
        if (-not $svcByProcId.ContainsKey($procId)) { $svcByProcId[$procId] = @() }
        $svcByProcId[$procId] += $_.Name
    }

# ---------------- Port Labels ----------------
$portMap = @{
    22="Remote (ssh)"; 80="HTTP"; 443="HTTPS"; 3389="Remote (rdp)"
    445="File Share (smb)"; 135="RPC"; 53="DNS"
    389="Domain Controller (ldap)"; 636="Domain Controller (ldaps)"
    88="Domain Controller (kerberos)"
    1433="Database (mssql)"; 3306="Database (mysql)"; 5432="Database (postgres)"
    25="Mail (smtp)"; 110="Mail (pop3)"; 143="Mail (imap)"
    587="Mail (submission)"; 5985="Remote (winrm)"
    5986="Remote (winrm-https)"
}

# ---------------- Report ----------------
Add "Inventory Report"
Add ("Generated: {0}" -f (Get-Date))
Add ("Running as Admin: {0}" -f $isAdmin)
Add ""

Add "Host:"
Add ("  {0}" -f $hostname)
Add ""

Add "Operating System:"
if ($os) { Add ("  {0} (Version {1}, Build {2})" -f $os.Caption, $os.Version, $os.BuildNumber) }
else { Add "  (Unable to read OS info)" }
Add ""

Add "Network (IPv4):"
if ($netCfg -and $netCfg.Count -gt 0) {
    foreach ($n in $netCfg) {
        $ip  = $n.IPv4Address.IPAddress
        $gw  = $n.IPv4DefaultGateway.NextHop
        $dns = ($n.DNSServer.ServerAddresses -join ", ")
        Add ("  {0}  IP:{1}  GW:{2}  DNS:{3}" -f $n.InterfaceAlias, $ip, $gw, $dns)
    }
} else {
    Add "  (none found or unable to query)"
}
Add ""

Add "Listening Ports (Quick Summary):"
if (-not $listen -or $listen.Count -eq 0) {
    Add "  (none)"
} else {
    foreach ($p in ($listen | Sort-Object Port,Proto | Select-Object -First 40)) {
        $label = if ($portMap.ContainsKey($p.Port)) { $portMap[$p.Port] } else { "" }
        if ($label) { Add ("  {0,5}/{1}  {2}" -f $p.Port, $p.Proto, $label) }
        else { Add ("  {0,5}/{1}" -f $p.Port, $p.Proto) }
    }
}
Add ""

$mapped   = $listen | Where-Object { $portMap.ContainsKey($_.Port) }
$unmapped = $listen | Where-Object { -not $portMap.ContainsKey($_.Port) }

Add "Required Ports (mapped):"
if ($mapped) {
    foreach ($m in ($mapped | Sort-Object Port,Proto -Unique)) {
        Add ("  {0,5}/{1}  -> {2}" -f $m.Port, $m.Proto, $portMap[$m.Port])
    }
} else { Add "  (none)" }
Add ""

Add "Other Listening Ports:"
if ($unmapped) {
    foreach ($u in ($unmapped | Sort-Object Port,Proto -Unique)) {
        Add ("  {0}/{1}" -f $u.Port, $u.Proto)
    }
} else { Add "  (none)" }
Add ""

Add "Evidence (Port -> ProcId -> Process -> Service):"
foreach ($row in ($listen | Sort-Object Port,Proto,ProcId)) {
    $procId = [int]$row.ProcId
    $proc   = if ($procMap.ContainsKey($procId)) { $procMap[$procId] } else { "UNKNOWN" }
    $svcs   = if ($svcByProcId.ContainsKey($procId)) { (($svcByProcId[$procId] | Sort-Object -Unique) -join ",") } else { "" }

    if ($svcs) {
        Add ("  {0,5}/{1,-3}  ProcId:{2,-6}  Proc:{3,-18}  Svc:{4}" -f $row.Port, $row.Proto, $procId, $proc, $svcs)
    } else {
        Add ("  {0,5}/{1,-3}  ProcId:{2,-6}  Proc:{3}" -f $row.Port, $row.Proto, $procId, $proc)
    }
}
Add ""

Add "Containers:"
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Add "  Docker detected:"
    try {
        docker ps -a --format '{{.Names}} | {{.Image}} | {{.Status}} | {{.Ports}}' |
            ForEach-Object { Add ("  " + $_) }
    } catch { Add "  (docker command failed)" }
} else {
    Add "  Docker not installed."
}

Add ""
Add ("Saved to: {0}" -f $outFile)

Write-Host "Saved: $outFile"
