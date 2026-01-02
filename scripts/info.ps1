param (
    [Parameter(Mandatory=$true)]
    [string]$Title
)

$t = $Title.ToLower().Trim()

# default template
$Inventory = @{
    Hostnames = "N/A"
    IPs = "N/A"
    OS = "N/A"
    Role = "Documentation / Comms"
    Services = "N/A"
    Ports = "N/A"
    Checks = "N/A"
    Notes = "Non-technical inject"
}

if ($t -like "*zerologon*") {
    $Inventory = @{
        Hostnames = "dc01"
        IPs = "10.0.0.10"
        OS = "Windows Server 2019/2022"
        Role = "Domain Controller"
        Services = "lsass.exe, Netlogon, DNS, KDC"
        Ports = "53,88,135,389,445,464,636,3268"
        Checks = "dcdiag; nltest; Get-ADDomain"
        Notes = "Exploit evidence + AD health validation"
    }
}
elseif ($t -like "*siem*") {
    $Inventory = @{
        Hostnames = "siem01"
        IPs = "10.0.0.20"
        OS = "Linux (Ubuntu)"
        Role = "SIEM"
        Services = "elasticsearch, kibana, ingest"
        Ports = "5601,9200,5044,514"
        Checks = "systemctl status elasticsearch kibana"
        Notes = "Replace with Splunk/Wazuh/etc."
    }
}

# output as object (better than text)
[pscustomobject]$Inventory
