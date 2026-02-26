# Firewall + Network Snapshot (CCDC-friendly)

param(
    [string]$Root = "C:\CCDC\Backups"
)

$ts   = Get-Date -Format "yyyyMMdd_HHmmss"
$base = Join-Path $Root $ts

New-Item -ItemType Directory -Path $base -Force | Out-Null
Write-Host "Creating snapshot at $base"

# 1) Firewall (RESTORE-READY)
try {
    netsh advfirewall export (Join-Path $base "firewall.wfw") | Out-Null
} catch {
    "firewall export failed: $($_.Exception.Message)" | Out-File (Join-Path $base "firewall_export_error.txt") -Encoding UTF8 -Force
}

# 2) Firewall (HUMAN/DIFF-FRIENDLY)
try {
    Get-NetFirewallProfile |
        Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, NotifyOnListen, LogAllowed, LogBlocked |
        Format-Table -AutoSize | Out-String |
        Out-File (Join-Path $base "firewall_profiles.txt") -Encoding UTF8 -Force
} catch { }

try {
    Get-NetFirewallRule |
        Select-Object DisplayName, Enabled, Direction, Action, Profile, Group, Owner, PolicyStoreSource |
        Sort-Object Direction, Action, DisplayName |
        Export-Csv (Join-Path $base "firewall_rules.csv") -NoTypeInformation -Force
} catch { }

# 3) Local users/admins (quick access checks)
try { net user | Out-File (Join-Path $base "local_users.txt") -Encoding UTF8 -Force } catch { }
try { net localgroup administrators | Out-File (Join-Path $base "local_admins.txt") -Encoding UTF8 -Force } catch { }

# 4) Services (useful for “what broke” + persistence checking)
try {
    Get-CimInstance Win32_Service |
        Select-Object Name, DisplayName, State, StartMode, StartName, PathName |
        Sort-Object State, Name |
        Export-Csv (Join-Path $base "services.csv") -NoTypeInformation -Force
} catch { }

# 5) Network listeners + process map
try { netstat -ano | Out-File (Join-Path $base "netstat.txt") -Encoding UTF8 -Force } catch { }

try {
    Get-Process -ErrorAction SilentlyContinue |
        Select-Object Name, Id,
            @{n="WorkingSetMB";e={[math]::Round($_.WorkingSet64/1MB,1)}},
            @{n="Path";e={$_.Path}} |
        Sort-Object Name, Id |
        Export-Csv (Join-Path $base "processes.csv") -NoTypeInformation -Force
} catch { }

# 6) Scheduled tasks (smaller + searchable than LIST /v spam)
try {
    Get-ScheduledTask |
        Select-Object TaskName, TaskPath, State, Author |
        Export-Csv (Join-Path $base "scheduled_tasks.csv") -NoTypeInformation -Force
} catch { }

# Restore note (manual):
# netsh advfirewall import "C:\CCDC\Backups\<timestamp>\firewall.wfw"

Write-Host "Snapshot complete."
Write-Host "Folder: $base"
