# he-ddns-updater.ps1

$ipsite   = "https://4.ifcfg.me/ip"
$hostname = '<Dyn DNS Hostname to Update>'
$authkey  = '<Dyn DNS Auth Key>'
$ddnsurl  = 'https://dyn.dns.he.net/nic/update'
$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "SilentlyContinue"

function Write-hr1 {
    Write-Host ("-" * 80)
}

function Write-hr2 {
    Write-Host ("=" * 80)
}

function Get-WanIP {
    (Invoke-WebRequest -URI $ipsite).Content -replace "`n|`r"
}

Write-hr2
$ip = Get-WanIP

Write-Output "Setting DNS entry for $hostname to point to $ip"
Write-hr1
$postParams = @{password=$authkey; hostname=$hostname; myip=$ip}
$res = Invoke-WebRequest -URI $ddnsurl -Method POST -Body $postParams -DisableKeepAlive -ov ov -ev ev 

if ($res.StatusDescription -eq 'OK') {
    Write-Host "Success: Dynamic DNS for $hostname updated to $ip" -foreground "green"
} else {
    Write-Host "Failure updating Dynamic DNS for $hostname"
    Write-hr1
    Write-Host $ev -foreground "red"
}
Write-hr2
