# 00_preflight.ps1
# Read-only environment check (SAFE)

Write-Host "=== BLUE TEAM PREFLIGHT ===`n"

# Basic system info
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem

Write-Host "[Host]"
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "OS: $($os.Caption)"
Write-Host "Version: $($os.Version)"
Write-Host "Build: $($os.BuildNumber)`n"

# PowerShell info
Write-Host "[PowerShell]"
Write-Host "Version: $($PSVersionTable.PSVersion)`n"

# Admin check
Write-Host "[Privileges]"
$admin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($admin) {
    Write-Host "Running as ADMIN"
} else {
    Write-Host "Running as STANDARD USER"
}
Write-Host ""

# Domain info
Write-Host "[Domain]"
if ($cs.PartOfDomain) {
    Write-Host "Domain Joined: YES"
    Write-Host "Domain: $($cs.Domain)"
} else {
    Write-Host "Domain Joined: NO"
}
Write-Host ""

# Execution policy (informational only)
Write-Host "[Execution Policy]"
Get-ExecutionPolicy -List | Format-Table -AutoSize
Write-Host ""

# Write location test (non-destructive)
Write-Host "[Write Test]"
$testPath = "$env:TEMP\bt_write_test.txt"
try {
    "test" | Out-File $testPath -Force
    Remove-Item $testPath -Force
    Write-Host "Write access: OK (TEMP)"
} catch {
    Write-Host "Write access: FAILED (TEMP)"
}

Write-Host "`n=== PREFLIGHT COMPLETE ==="
