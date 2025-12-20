#Requires -Version 6
[cmdletbinding()]
Param(
    [Parameter(Mandatory=$false)]
    [String]$Hostname = 'pve1.tainik.net',

    [Parameter(Mandatory=$false)]
    [String]$IPAddress = '192.168.0.1'
)

$term_width = [Console]::BufferWidth

$hostInfo = @{
    name = $Hostname
    content = $IPAddress
}
$params = @{
    Uri = 'https://api.nextdns.io/profiles/8bbb9d/rewrites'
    Headers = @{ 
        'X-Api-Key' = $Env:NEXTDNS_API_KEY 
        'Content-Type' = 'application/json'
    }
    Method = 'Post'
    Body = $hostInfo | ConvertTo-Json
}

Invoke-RestMethod @params -Verbose

#foreach ($h in $res.data) {
#    "{0}`t{1}" -f $h.content, $h.name
#}