$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$base = "C:\CCDC\Backups\$ts"
New-Item -ItemType Directory -Path $base -Force | Out-Null

Write-Host "Creating snapshot at $base"

netsh advfirewall export "$base\firewall.wfw" | Out-Null

net user > "$base\local_users.txt"
net localgroup administrators > "$base\local_admins.txt"

Get-Service | Sort-Object Status,Name | Out-File "$base\services.txt"

netstat -ano > "$base\netstat.txt"

schtasks /query /fo LIST /v > "$base\schtasks.txt"

Write-Host "Snapshot complete."
