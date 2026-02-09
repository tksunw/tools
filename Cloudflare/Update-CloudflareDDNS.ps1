#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates Cloudflare DNS A and/or AAAA records with current public IP address(es) for dynamic DNS.

.DESCRIPTION
    This script retrieves the current public IP address and updates Cloudflare DNS records.
    It includes idempotency checks to avoid unnecessary API calls when the IP hasn't changed, proper error
    handling, and security best practices for handling API credentials.

.PARAMETER ZoneID
    The Cloudflare Zone ID containing the DNS record to update.
    Can be provided via parameter or CLOUDFLARE_ZONE_ID environment variable.

.PARAMETER RecordID
    The Cloudflare DNS Record ID to update.
    Can be provided via parameter or CLOUDFLARE_RECORD_ID environment variable.

.PARAMETER RecordName
    The DNS record name (e.g., "example.com" or "subdomain.example.com").
    Can be provided via parameter or CLOUDFLARE_RECORD_NAME environment variable.

.PARAMETER RecordType
    DNS record type for single-record mode. Supported values: A, AAAA.
    Default: A

.PARAMETER DualStack
    Updates both IPv4 (A) and IPv6 (AAAA) records in one run using separate record IDs.
    Uses CLOUDFLARE_RECORD_ID_V4/CLOUDFLARE_RECORD_NAME_V4 and
    CLOUDFLARE_RECORD_ID_V6/CLOUDFLARE_RECORD_NAME_V6 when parameters are omitted.

.PARAMETER CloudflareApiKey
    The Cloudflare API token with permissions to update DNS records.
    Can be provided via parameter or CLOUDFLARE_API_KEY environment variable.
    For security, it's recommended to use environment variables rather than passing directly.

.EXAMPLE
    ./Update-CloudflareDDNS.ps1
    Updates the DNS record using environment variables for all parameters.

.EXAMPLE
    ./Update-CloudflareDDNS.ps1 -ZoneID "abc123" -RecordID "def456" -RecordName "home.example.com" -CloudflareApiKey "your-api-token"
    Updates the DNS record using explicit parameters.

.EXAMPLE
    ./Update-CloudflareDDNS.ps1 -Verbose
    Updates the DNS record with verbose output showing each step of the process.

.EXAMPLE
    ./Update-CloudflareDDNS.ps1 -RecordType AAAA
    Updates a single IPv6 DNS record using the detected public IPv6 address.

.EXAMPLE
    ./Update-CloudflareDDNS.ps1 -DualStack -RecordIDv4 "id4" -RecordNamev4 "home.example.com" -RecordIDv6 "id6" -RecordNamev6 "home.example.com"
    Updates both A and AAAA records in one execution.

.NOTES
    Author: Tim
    Requires: PowerShell 7+

    Required Environment Variables (if not using parameters):
    - CLOUDFLARE_ZONE_ID
    - CLOUDFLARE_RECORD_ID
    - CLOUDFLARE_RECORD_NAME
    - CLOUDFLARE_API_KEY

    To find your Zone ID and Record ID:
    1. Log into Cloudflare dashboard
    2. Select your domain
    3. Zone ID is shown on the overview page
    4. Record ID can be found via the Cloudflare API or browser dev tools

.LINK
    https://api.cloudflare.com/#dns-records-for-a-zone-update-dns-record
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [String]$ZoneID = $Env:CLOUDFLARE_ZONE_ID,

    [Parameter(Mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [String]$RecordID = $Env:CLOUDFLARE_RECORD_ID,

    [Parameter(Mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [String]$RecordName = $Env:CLOUDFLARE_RECORD_NAME,

    [Parameter(Mandatory=$False)]
    [ValidateSet('A', 'AAAA')]
    [String]$RecordType = 'A',

    [Parameter(Mandatory=$False)]
    [switch]$DualStack,

    [Parameter(Mandatory=$False)]
    [String]$RecordIDv4 = $Env:CLOUDFLARE_RECORD_ID_V4,

    [Parameter(Mandatory=$False)]
    [String]$RecordNamev4 = $Env:CLOUDFLARE_RECORD_NAME_V4,

    [Parameter(Mandatory=$False)]
    [String]$RecordIDv6 = $Env:CLOUDFLARE_RECORD_ID_V6,

    [Parameter(Mandatory=$False)]
    [String]$RecordNamev6 = $Env:CLOUDFLARE_RECORD_NAME_V6,

    [Parameter(Mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [String]$CloudflareApiKey = $Env:CLOUDFLARE_API_KEY
)

$ErrorActionPreference = 'Stop'

function Test-TransientHttpStatusCode {
    param([int]$StatusCode)
    return $StatusCode -eq 408 -or $StatusCode -eq 429 -or $StatusCode -ge 500
}

function Get-CloudflareErrorDetails {
    param($ErrorPayload)
    if (-not $ErrorPayload) {
        return 'Unknown Cloudflare API error'
    }
    return ($ErrorPayload | ConvertTo-Json -Compress)
}

function Invoke-CloudflareApi {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Request,
        [int]$TimeoutSec = 15,
        [int]$MaxRetries = 2
    )

    $attempt = 0
    while ($true) {
        $attempt++
        try {
            return Invoke-RestMethod @Request -TimeoutSec $TimeoutSec -ErrorAction Stop
        } catch {
            $statusCode = 0
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }

            $isTransient = Test-TransientHttpStatusCode -StatusCode $statusCode
            if ($attempt -le $MaxRetries -and $isTransient) {
                $backoffSeconds = [math]::Min(8, [math]::Pow(2, $attempt))
                Write-Verbose "Transient Cloudflare API error (status: $statusCode). Retrying in $backoffSeconds second(s)..."
                Start-Sleep -Seconds $backoffSeconds
                continue
            }

            throw
        }
    }
}

function Get-PublicIP {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('IPv4', 'IPv6')]
        [string]$AddressFamily
    )

    $servicesByFamily = @{
        IPv4 = @('https://api4.ipify.org', 'https://ipv4.icanhazip.com', 'https://ident.me')
        IPv6 = @('https://api6.ipify.org', 'https://ipv6.icanhazip.com')
    }

    foreach ($service in $servicesByFamily[$AddressFamily]) {
        try {
            Write-Verbose "Getting public $AddressFamily address from $service"
            $candidate = (Invoke-RestMethod -Uri $service -TimeoutSec 10 -ErrorAction Stop).ToString().Trim()
            $ip = [ipaddress]$candidate

            if (
                ($AddressFamily -eq 'IPv4' -and $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) -or
                ($AddressFamily -eq 'IPv6' -and $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6)
            ) {
                Write-Verbose "Service returned non-$AddressFamily value [$candidate], trying next service."
                continue
            }

            return $ip.IPAddressToString
        } catch {
            Write-Verbose "IP service failed ($service): $($_.Exception.Message)"
        }
    }

    throw "Failed to retrieve a valid public $AddressFamily address from all configured services."
}

function Update-CloudflareRecord {
    param(
        [Parameter(Mandatory = $true)][string]$ZoneID,
        [Parameter(Mandatory = $true)][string]$RecordID,
        [Parameter(Mandatory = $true)][string]$RecordName,
        [Parameter(Mandatory = $true)][ValidateSet('A', 'AAAA')][string]$RecordType,
        [Parameter(Mandatory = $true)][string]$TargetIP,
        [Parameter(Mandatory = $true)][hashtable]$Headers
    )

    $recordUri = "https://api.cloudflare.com/client/v4/zones/$ZoneID/dns_records/$RecordID"
    Write-Verbose "Reading current DNS record for $RecordName ($RecordType)"

    $currentRecord = Invoke-CloudflareApi -Request @{
        Uri = $recordUri
        Headers = $Headers
        Method = 'GET'
    }

    if (-not $currentRecord.success) {
        throw "Cloudflare API read failed: $(Get-CloudflareErrorDetails -ErrorPayload $currentRecord.errors)"
    }

    if ($currentRecord.result.name -ne $RecordName) {
        throw "Record name mismatch for ID '$RecordID'. Expected '$RecordName', found '$($currentRecord.result.name)'."
    }

    if ($currentRecord.result.type -ne $RecordType) {
        throw "Record type mismatch for ID '$RecordID'. Expected '$RecordType', found '$($currentRecord.result.type)'."
    }

    $currentIP = $currentRecord.result.content
    Write-Verbose "Current DNS IP for $RecordName ($RecordType): $currentIP"

    if ($currentIP -eq $TargetIP) {
        Write-Verbose "Record already matches target IP ($TargetIP); no update needed."
        return [pscustomobject]@{
            Name = $RecordName
            Type = $RecordType
            IP = $currentIP
            Changed = $false
            Result = $currentRecord.result
        }
    }

    # Use PATCH to update only content and preserve existing record settings.
    $payload = @{ content = $TargetIP }
    Write-Verbose "Updating $RecordName ($RecordType) to $TargetIP"

    $response = Invoke-CloudflareApi -Request @{
        Uri = $recordUri
        Headers = $Headers
        Method = 'PATCH'
        Body = ($payload | ConvertTo-Json -Compress)
    }

    if (-not $response.success) {
        throw "Cloudflare API update failed: $(Get-CloudflareErrorDetails -ErrorPayload $response.errors)"
    }

    return [pscustomobject]@{
        Name = $RecordName
        Type = $RecordType
        IP = $response.result.content
        Changed = $true
        Result = $response.result
    }
}

# Validate required security/auth parameters
if (-not $ZoneID -or -not $CloudflareApiKey) {
    throw "Missing required parameters. Ensure CLOUDFLARE_ZONE_ID and CLOUDFLARE_API_KEY are set."
}

Write-Verbose "ZoneID: $ZoneID"

# Prepare Cloudflare API headers
$headers = @{
    Authorization = "Bearer $CloudflareApiKey"
    'Content-Type' = 'application/json'
    'User-Agent' = 'Update-CloudflareDDNS.ps1/3.0'
}

# Validate required record parameters based on mode and map to update operations.
$operations = New-Object System.Collections.Generic.List[object]
if ($DualStack) {
    if (-not $RecordIDv4) {
        $RecordIDv4 = $RecordID
    }
    if (-not $RecordNamev4) {
        $RecordNamev4 = $RecordName
    }

    if (-not $RecordIDv4 -or -not $RecordNamev4 -or -not $RecordIDv6 -or -not $RecordNamev6) {
        throw "DualStack mode requires RecordIDv4/RecordNamev4 and RecordIDv6/RecordNamev6 (or legacy RecordID/RecordName for v4)."
    }

    $operations.Add([pscustomobject]@{ RecordID = $RecordIDv4; RecordName = $RecordNamev4; RecordType = 'A' }) | Out-Null
    $operations.Add([pscustomobject]@{ RecordID = $RecordIDv6; RecordName = $RecordNamev6; RecordType = 'AAAA' }) | Out-Null
} else {
    if (-not $RecordID -or -not $RecordName) {
        throw "Missing required parameters for single-record mode. Ensure CLOUDFLARE_RECORD_ID and CLOUDFLARE_RECORD_NAME are set."
    }

    $operations.Add([pscustomobject]@{ RecordID = $RecordID; RecordName = $RecordName; RecordType = $RecordType }) | Out-Null
}

$results = foreach ($operation in $operations) {
    $family = if ($operation.RecordType -eq 'AAAA') { 'IPv6' } else { 'IPv4' }
    $ip = Get-PublicIP -AddressFamily $family
    Write-Verbose "Current public $family address: $ip"

    Update-CloudflareRecord `
        -ZoneID $ZoneID `
        -RecordID $operation.RecordID `
        -RecordName $operation.RecordName `
        -RecordType $operation.RecordType `
        -TargetIP $ip `
        -Headers $headers
}

$updated = @($results | Where-Object { $_.Changed })
if ($updated.Count -gt 0) {
    foreach ($item in $updated) {
        Write-Information "Updated $($item.Type) record '$($item.Name)' to $($item.IP)" -InformationAction Continue
    }
} else {
    Write-Information "All DNS records are already up to date." -InformationAction Continue
}

return $results
