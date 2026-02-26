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

# NOTE: $PID is reserved (case-insensitive). Don't use $pid.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

# ---------------- OS + Network ----------------
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

$netCfg = @()
try {
    $netCfg = Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.IPv4Address }
} catch { $netCfg = @() }

# ---------------- Listening Ports ----------------
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

# ---------------- Service Map (ProcId -> service names) ----------------
$svcByProcId = @{}
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessId -gt 0 } |
    ForEach-Object {
        $p = [int]$_.ProcessId
        if (-not $svcByProcId.ContainsKey($p)) { $svcByProcId[$p] = @() }
        $svcByProcId[$p] += $_.Name
    }

function Compress-List {
    param(
        [string[]]$Items,
        [int]$Max = 5
    )
    if (-not $Items -or $Items.Count -eq 0) { return "" }
    $u = $Items | Sort-Object -Unique
    if ($u.Count -le $Max) { return ($u -join ",") }
    $head = $u[0..($Max-1)] -join ","
    return "$head, ... (+$($u.Count - $Max) more)"
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

# ---- Compact summaries ----
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

Add "Required Ports (mapped):"
$mapped = $listen | Where-Object { $portMap.ContainsKey($_.Port) } | Sort-Object Port,Proto -Unique
if ($mapped) {
    foreach ($m in $mapped) { Add ("  {0,5}/{1}  -> {2}" -f $m.Port, $m.Proto, $portMap[$m.Port]) }
} else { Add "  (none)" }
Add ""

Add "Other Listening Ports:"
$unmapped = $listen | Where-Object { -not $portMap.ContainsKey($_.Port) } | Sort-Object Port,Proto -Unique
if ($unmapped) {
    foreach ($u in $unmapped) { Add ("  {0}/{1}" -f $u.Port, $u.Proto) }
} else { Add "  (none)" }
Add ""

# ---- Evidence grouped by process (THIS fixes the “pages of mess”) ----
Add "Evidence (grouped by process):"
if (-not $listen -or $listen.Count -eq 0) {
    Add "  (none)"
} else {
    $groups = $listen | Group-Object ProcId | Sort-Object { $_.Group.Count } -Descending

    foreach ($g in $groups) {
        $procId = [int]$g.Name
        $procName = if ($procMap.ContainsKey($procId)) { $procMap[$procId] } else { "UNKNOWN" }

        # Build ports list like: 80/tcp, 443/tcp, 5353/udp
        $ports = $g.Group |
            Sort-Object Port,Proto |
            ForEach-Object {
                $lbl = if ($portMap.ContainsKey($_.Port)) { " ($($portMap[$_.Port]))" } else { "" }
                "{0}/{1}{2}" -f $_.Port, $_.Proto, $lbl
            }
        $portsText = Compress-List -Items $ports -Max 12

        $svcsText = ""
        if ($svcByProcId.ContainsKey($procId)) {
            $svcsText = Compress-List -Items $svcByProcId[$procId] -Max 6
        }

        Add ("  ProcId:{0}  Proc:{1}" -f $procId, $procName)
        Add ("    Ports: {0}" -f $portsText)
        if ($svcsText) { Add ("    Svcs:  {0}" -f $svcsText) }
        Add ""
    }
}

# ---- Docker (kept readable) ----
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
