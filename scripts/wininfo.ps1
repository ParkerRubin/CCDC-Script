# Network_Inventory_Windows.ps1
# Saves inventory to a folder in the CURRENT working directory

$hostname  = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"

# Folder + file (relative path = wherever you cd'd into)
$folderName = "Inventory_${hostname}_${timestamp}"
$outDir     = Join-Path (Get-Location) $folderName
$outFile    = Join-Path $outDir "inventory.txt"

# Create folder
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Write-Section {
    param($Title)
    "`n==== $Title ====`n" | Out-File -FilePath $outFile -Append -Encoding utf8
}

# Header
"Network Inventory Report" | Out-File $outFile -Encoding utf8
("Generated: {0}" -f (Get-Date)) | Out-File $outFile -Append
("Host:      {0}" -f $hostname) | Out-File $outFile -Append

# Host info
Write-Section "Host Identification"
$cs = Get-CimInstance Win32_ComputerSystem
("Hostname: {0}" -f $hostname) | Out-File $outFile -Append
("Domain:   {0}" -f $cs.Domain) | Out-File $outFile -Append
("Role:     {0}" -f $(if ($cs.PartOfDomain) {"Domain-Joined"} else {"Workgroup"})) | Out-File $outFile -Append

# OS
Write-Section "Operating System"
$os = Get-CimInstance Win32_OperatingSystem
("OS:      {0}" -f $os.Caption) | Out-File $outFile -Append
("Version: {0}" -f $os.Version) | Out-File $outFile -Append
("Build:   {0}" -f $os.BuildNumber) | Out-File $outFile -Append
("Boot:    {0}" -f $os.LastBootUpTime) | Out-File $outFile -Append

# IPs
Write-Section "IP Addresses (IPv4)"
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254*" -and $_.IPAddress -ne "127.0.0.1" } |
    Sort-Object InterfaceAlias |
    ForEach-Object {
        ("{0,-25} {1,-15}" -f $_.InterfaceAlias, $_.IPAddress)
    } | Out-File $outFile -Append -Encoding utf8

# Services
Write-Section "Running Services"
Get-Service |
    Where-Object Status -eq "Running" |
    Sort-Object DisplayName |
    ForEach-Object {
        ("{0,-55} ({1})" -f $_.DisplayName, $_.Name)
    } | Out-File $outFile -Append -Encoding utf8

# Ports
Write-Section "Listening Ports (TCP/UDP)"
$procs = Get-Process | Select-Object Id, ProcessName

"TCP:" | Out-File $outFile -Append
Get-NetTCPConnection -State Listen |
    ForEach-Object {
        $p = ($procs | Where-Object Id -eq $_.OwningProcess).ProcessName
        if (-not $p) { $p = "UNKNOWN" }
        ("{0,6}  PID:{1,-6}  {2}" -f $_.LocalPort, $_.OwningProcess, $p)
    } | Sort-Object | Out-File $outFile -Append -Encoding utf8

"`nUDP:" | Out-File $outFile -Append
Get-NetUDPEndpoint |
    ForEach-Object {
        $p = ($procs | Where-Object Id -eq $_.OwningProcess).ProcessName
        if (-not $p) { $p = "UNKNOWN" }
        ("{0,6}  PID:{1,-6}  {2}" -f $_.LocalPort, $_.OwningProcess, $p)
    } | Sort-Object | Out-File $outFile -Append -Encoding utf8

# Containers
Write-Section "Containers (Docker)"
if (Get-Command docker -ErrorAction SilentlyContinue) {
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" |
        Out-File $outFile -Append -Encoding utf8
} else {
    "Docker not installed." | Out-File $outFile -Append
}

Write-Section "Complete"
("Output directory: {0}" -f $outDir) | Out-File $outFile -Append

Write-Host "Inventory saved to:"
Write-Host "  $outDir"
