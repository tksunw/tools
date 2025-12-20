#!/usr/bin/env pwsh
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False)]
    [ValidateNotNullorEmpty()]
    [String]$ZoneID = $Env:CLOUDFLARE_ZONE_ID,

    [Parameter(Mandatory=$False)]
    [String]$RecordID = $Env:CLOUDFLARE_RECORD_ID,

    [Parameter(Mandatory=$False)]
    [String]$RecordName = $Env:CLOUDFLARE_RECORD_NAME,

    [Parameter(Mandatory=$False)]
    [String]$CloudflareApiKey = $Env:CLOUDFLARE_API_KEY
)


End {

    "ZoneID: $ZoneID"
    "RecordID: $RecordID"
    "RecordName: $RecordName"
    "API KEY: $CloudflareApiKey"

    Write-Information "Getting PUBLIC IP from ident.me"
    $uri1 = ("https://ident.me" -f $V)
    $uri2 = ("https://tnedi.me" -f $V)
    try {
        $ip = Invoke-RestMethod -Uri $uri1
    } catch {
        $ip = Invoke-RestMethod -Uri $uri2
    }

    Write-Information "Checking if ${ip} is a valid IP"
    if (-not [ipaddress]$ip) {
        Throw "Error getting Public IP.  Got [${ip}]"
    }

    $uri = "https://api.cloudflare.com/client/v4/zones/${ZoneID}/dns_records/${RecordID}"
    
    $payload = @{
        "type" = "A" 
        "name" = ${RecordName}
        "content" = ${ip}
    } 

    $params = @{
        Uri = $uri
        Headers = @{ 
        Authorization = "Bearer ${CloudflareApiKey}"
            'Content-Type' = 'application/json' 
        }
        Method = 'PUT'
        Body = ($payload | ConvertTo-Json)
    }


    Write-Information "Setting DDNS IP for $RecordName to ${ip}"
    try {
        $data = Invoke-RestMethod @params 
    } catch {
        "Exception Caught: $($_.Exception.Message)"
    }
    return $data.result

    [GC]::Collect()
}

