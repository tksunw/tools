#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates a Cloudflare DNS A record with the current public IP address for dynamic DNS.

.DESCRIPTION
    This script retrieves the current public IP address and updates a specified Cloudflare DNS A record.
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
    [ValidateNotNullOrEmpty()]
    [String]$CloudflareApiKey = $Env:CLOUDFLARE_API_KEY
)

$ErrorActionPreference = 'Stop'

# Validate all required parameters are provided
if (-not $ZoneID -or -not $RecordID -or -not $RecordName -or -not $CloudflareApiKey) {
    throw "Missing required parameters. Ensure CLOUDFLARE_ZONE_ID, CLOUDFLARE_RECORD_ID, CLOUDFLARE_RECORD_NAME, and CLOUDFLARE_API_KEY are set."
}

Write-Verbose "ZoneID: $ZoneID"
Write-Verbose "RecordID: $RecordID"
Write-Verbose "RecordName: $RecordName"

# Get current public IP
Write-Verbose "Getting public IP from ident.me"
$uri1 = "https://ident.me"
$uri2 = "https://tnedi.me"

try {
    $ip = Invoke-RestMethod -Uri $uri1 -TimeoutSec 10
} catch {
    Write-Verbose "Primary IP service failed, trying backup..."
    try {
        $ip = Invoke-RestMethod -Uri $uri2 -TimeoutSec 10
    } catch {
        throw "Failed to retrieve public IP from both services: $($_.Exception.Message)"
    }
}

# Validate IP address
Write-Verbose "Validating IP: $ip"
try {
    $null = [ipaddress]$ip
} catch {
    throw "Invalid IP address received: [$ip]"
}

Write-Verbose "Current public IP: $ip"

# Prepare Cloudflare API headers
$headers = @{
    Authorization = "Bearer $CloudflareApiKey"
    'Content-Type' = 'application/json'
}

# Check current DNS record to avoid unnecessary updates
$getUri = "https://api.cloudflare.com/client/v4/zones/$ZoneID/dns_records/$RecordID"
try {
    $currentRecord = Invoke-RestMethod -Uri $getUri -Headers $headers -Method Get

    if (-not $currentRecord.success) {
        throw "Cloudflare API error: $($currentRecord.errors | ConvertTo-Json -Compress)"
    }

    $currentIP = $currentRecord.result.content
    Write-Verbose "Current DNS IP: $currentIP"

    if ($currentIP -eq $ip) {
        Write-Verbose "DNS record already has the correct IP ($ip). No update needed."
        return $currentRecord.result
    }
} catch {
    Write-Warning "Could not fetch current DNS record: $($_.Exception.Message). Proceeding with update..."
}

# Update DNS record
$payload = @{
    type = "A"
    name = $RecordName
    content = $ip
}

$params = @{
    Uri = "https://api.cloudflare.com/client/v4/zones/$ZoneID/dns_records/$RecordID"
    Headers = $headers
    Method = 'PUT'
    Body = ($payload | ConvertTo-Json)
}

Write-Verbose "Updating DDNS IP for $RecordName to $ip"
try {
    $response = Invoke-RestMethod @params

    if (-not $response.success) {
        throw "Cloudflare API update failed: $($response.errors | ConvertTo-Json -Compress)"
    }

    Write-Host "Successfully updated DNS record for $RecordName to $ip" -ForegroundColor Green
    return $response.result

} catch {
    throw "Failed to update DNS record: $($_.Exception.Message)"
}

