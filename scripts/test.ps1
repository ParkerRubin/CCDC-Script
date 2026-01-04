# net_inventory.ps1
# Usage:
#   .\net_inventory.ps1 -Subnet "192.168.50" -Start 1 -End 254
# Outputs summary to screen (and optionally to a file)

param(
  [Parameter(Mandatory=$true)]
  [string]$Subnet,              # e.g. "192.168.50"
  [int]$Start = 1,
  [int]$End = 254,
  [int]$TimeoutMs = 200,
  [string]$OutFile = ""         # e.g. ".\Network_Inventory_Discovered.txt"
)

# Common ports -> labels (edit if your env differs)
$PortMap = @(
  @{ Port=22;   Label="Remote (ssh)" },
  @{ Port=3389; Label="Remote (rdp)" },

  @{ Port=80;   Label="HTTP" },
  @{ Port=443;  Label="HTTPS" },

  @{ Port=53;   Label="DNS" },
  @{ Port=88;   Label="Kerberos" },
  @{ Port=389;  Label="LDAP" },
  @{ Port=445;  Label="SMB" },

  @{ Port=3306; Label="Database (mysql)" },
  @{ Port=1433; Label="Database (mssql)" },
  @{ Port=5432; Label="Database (postgres)" },

  @{ Port=25;   Label="Mail (smtp)" },
  @{ Port=110;  Label="Mail (pop3)" },
  @{ Port=143;  Label="Mail (imap)" },
  @{ Port=993;  Label="Mail (imaps)" },
  @{ Port=995;  Label="Mail (pop3s)" },

  @{ Port=514;  Label="Syslog (udp)" },  # UDP note: this script checks TCP only
  @{ Port=5044; Label="Log Ingest (beats)" }
)

function Test-TcpPort {
  param([string]$Ip, [int]$Port, [int]$TimeoutMs)
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $iar = $client.BeginConnect($Ip, $Port, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
    if ($ok -and $client.Connected) { $client.Close(); return $true }
    $client.Close(); return $false
  } catch { return $false }
}

function Guess-OS {
  param([string[]]$ServiceLabels)
  # Very rough heuristic like your friend’s output
  if ($ServiceLabels -match "SMB|Kerberos|LDAP") { return "Windows (likely)" }
  if ($ServiceLabels -match "Remote \(ssh\)" -and -not ($ServiceLabels -match "Remote \(rdp\)")) { return "Linux (likely)" }
  if ($ServiceLabels -match "Remote \(rdp\)" -and -not ($ServiceLabels -match "Remote \(ssh\)")) { return "Windows (likely)" }
  return "Unknown"
}

$lines = New-Object System.Collections.Generic.List[string]

$header = @(
"=================================================="
"Summary of Hosts:"
"=================================================="
) -join "`n"

Write-Host $header
$lines.AddRange($header -split "`n")

for ($i=$Start; $i -le $End; $i++) {
  $ip = "$Subnet.$i"

  # Fast "is it up" check (ICMP)
  $alive = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
  if (-not $alive) { continue }

  # Optional: hostname (may be blank depending on DNS)
  $hostname = $null
  try {
    $hostname = ([System.Net.Dns]::GetHostEntry($ip)).HostName
  } catch { $hostname = $null }

  $servicesFound = New-Object System.Collections.Generic.List[string]
  $portsFound = New-Object System.Collections.Generic.List[string]

  foreach ($p in $PortMap) {
    $port = [int]$p.Port
    # NOTE: This checks TCP only. (UDP needs a different approach.)
    if (Test-TcpPort -Ip $ip -Port $port -TimeoutMs $TimeoutMs) {
      $servicesFound.Add($p.Label)
      $portsFound.Add("$($p.Label):$port")
    }
  }

  # Dedupe labels
  $servicesUnique = $servicesFound | Sort-Object -Unique
  $portsUnique = $portsFound | Sort-Object -Unique

  $osGuess = Guess-OS -ServiceLabels $servicesUnique

  $hostLine = if ($hostname) { "Host: $ip ($hostname)" } else { "Host: $ip" }
  $svcLine  = if ($servicesUnique.Count) { "  Services: " + ($servicesUnique -join ", ") } else { "  Services: (none detected on scanned ports)" }
  $portLine = if ($portsUnique.Count) { "  Ports: " + ($portsUnique -join ", ") } else { "  Ports: (none)" }

  $block = @(
    $hostLine
    "  OS: $osGuess"
    $svcLine
    $portLine
    "--------------------------------------------------"
  )

  $block | ForEach-Object { Write-Host $_ }
  $lines.AddRange($block)
}

if ($OutFile) {
  $lines | Out-File -Encoding UTF8 $OutFile
  Write-Host "`nSaved: $OutFile"
}
