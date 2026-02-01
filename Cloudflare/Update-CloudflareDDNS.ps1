#!/usr/bin/env pwsh
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

