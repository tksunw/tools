#Requires -Version 6
[cmdletbinding()]
Param(
    [Parameter(Mandatory=$false)]
    [String]$HostsFile='/etc/hosts'
)

$term_width = [Console]::BufferWidth

$params = @{
    Uri = 'https://api.nextdns.io/profiles/8bbb9d/rewrites'
    Headers = @{ 'X-Api-Key' = $Env:NEXTDNS_API_KEY }
    Method = 'GET'
}

$res = Invoke-RestMethod @params

foreach ($h in $res.data) {
    "{0}`t{1}" -f $h.content, $h.name
}