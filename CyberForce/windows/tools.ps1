$BaseDir = "C:\CCDC"
$ToolDir = "$BaseDir\Tools\Sysinternals"

# Only pulling the tools actually used during triage - full suite download
# is unnecessary weight (and unnecessary download time) for a comp box.
# 64-bit only, for download speed - if you ever land on a 32-bit box,
# add the 32-bit filename/URL pair back in.
$Tools = @{
    "procexp64.exe"  = "https://live.sysinternals.com/procexp64.exe"
    "Autoruns64.exe" = "https://live.sysinternals.com/Autoruns64.exe"
    "sigcheck64.exe" = "https://live.sysinternals.com/sigcheck64.exe"
    "tcpview64.exe"  = "https://live.sysinternals.com/tcpview64.exe"
}

Write-Host "=== Installing Sysinternals Tools (Process Explorer, Autoruns, Sigcheck, TCPView - x64) ==="

New-Item -ItemType Directory -Path $ToolDir -Force | Out-Null

foreach ($name in $Tools.Keys) {
    $dest = Join-Path $ToolDir $name
    if (Test-Path $dest) {
        Write-Host "[=] $name already present, skipping."
        continue
    }

    Write-Host "[*] Downloading $name..."
    try {
        Invoke-WebRequest -Uri $Tools[$name] -OutFile $dest -ErrorAction Stop
    } catch {
        Write-Host "[!] Failed to download $name : $($_.Exception.Message)"
        Write-Host "[!] Assuming it's already staged in repo, or grab it manually from live.sysinternals.com."
    }
}

Get-ChildItem $ToolDir -Filter *.exe -ErrorAction SilentlyContinue | ForEach-Object {
    Unblock-File $_.FullName
}

Write-Host "[+] Sysinternals tools ready at $ToolDir"
