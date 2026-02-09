#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates Hurricane Electric DDNS record with the current public IPv4 address.

.DESCRIPTION
    Reads configuration from parameters or environment variables, discovers current public IPv4,
    and updates HE dynamic DNS endpoint only when needed by the provider.

.PARAMETER HostName
    Dynamic DNS hostname to update. Defaults to HE_DDNS_HOSTNAME env var.

.PARAMETER AuthKey
    Dynamic DNS key/password. Defaults to HE_DDNS_KEY env var.

.PARAMETER IpLookupSite
    Public IPv4 lookup endpoint. Default: https://4.ifcfg.me/ip

.PARAMETER DdnsUrl
    Hurricane Electric update endpoint. Default: https://dyn.dns.he.net/nic/update
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$HostName = $Env:HE_DDNS_HOSTNAME,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$AuthKey = $Env:HE_DDNS_KEY,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$IpLookupSite = 'https://4.ifcfg.me/ip',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DdnsUrl = 'https://dyn.dns.he.net/nic/update'
)

$ErrorActionPreference = 'Stop'

if (-not $HostName -or -not $AuthKey) {
    throw 'Missing required parameters. Set HE_DDNS_HOSTNAME and HE_DDNS_KEY or pass -HostName/-AuthKey.'
}

function Get-WanIPv4 {
    param([Parameter(Mandatory = $true)][string]$Uri)

    Write-Verbose "Retrieving public IPv4 from $Uri"
    $raw = (Invoke-WebRequest -Uri $Uri -TimeoutSec 10 -ErrorAction Stop).Content.Trim()
    try {
        $ip = [ipaddress]$raw
    } catch {
        throw "IP lookup response is not a valid IP address: [$raw]"
    }

    if ($ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Expected IPv4 address but received [$raw]"
    }

    return $ip.IPAddressToString
}

$ip = Get-WanIPv4 -Uri $IpLookupSite
Write-Information "Updating HE DDNS host '$HostName' to IPv4 $ip" -InformationAction Continue

$postParams = @{
    password = $AuthKey
    hostname = $HostName
    myip = $ip
}

try {
    $response = Invoke-WebRequest -Uri $DdnsUrl -Method POST -Body $postParams -TimeoutSec 10 -ErrorAction Stop
} catch {
    throw "Failed to update HE DDNS endpoint: $($_.Exception.Message)"
}

$body = if ($response.Content) { $response.Content.Trim().ToLowerInvariant() } else { '' }
if ($response.StatusCode -eq 200 -and ($body.StartsWith('good') -or $body.StartsWith('nochg'))) {
    Write-Information "Success: Dynamic DNS for $HostName is $ip ($body)" -InformationAction Continue
} else {
    throw "HE DDNS update failed for $HostName. HTTP $($response.StatusCode). Response: $($response.Content)"
}
