<#
.SYNOPSIS
Convers entries from a Unix/Linux style hosts file to NextDNS rewrite entries

.DESCRIPTION
This tool reads a 'hosts' file with white-space delimited entries in the format
<ipaddress> <hostname>
and creates NextDNS 'rewrite' entries for the host records.  Only the first
hostname is honored, so if you have and entry like:
10.0.0.1 webserver.public.com webhost

The 'webhost' nickname will be ignored.

.INPUTS 
None

.OUTPUTS
String. Informational Only.

.NOTES
Use it as you will, under the terms of the MIT License (https://opensource.org/license/mit/)

.LINK
https://nextdns.github.io/api/

.LINK
https://opensource.org/license/mit/

#>
#Requires -Version 6
[cmdletbinding()]
Param(
    [Parameter(Mandatory=$false)]
    [String]$HostsFile = '/etc/hosts'
)

BEGIN {
    if ($host.Name -match 'ISE Host') {
        $width = $host.UI.RawUI.BufferSize.Width
    } else { #if ($host.Name -eq 'ConsoleHost') {
        $width = [console]::BufferWidth
    }
    
    $logwidth = $width - 27
    #$infowidth = 0 - $logwidth + 8
    
    function format-color($color, $msg) {return "$($PSStyle.Foreground.${color})${msg}$($PSStyle.Reset)"}
    function format-style($style, $msg) {return "$($PSStyle.$style)${msg}$($PSStyle.Reset)"}
    
    function write-hr($char)     { write-info ($char * $logwidth) }    
    function write-info($msg)    { Write-Information -InformationAction Continue "[$(Get-Date)]: $msg" }
    function write-line($msg)    { write-host -NoNewline ("[{0}]: {1, $(0 - $logwidth + 8)}" -f $(Get-Date), $msg)}
    
    $resOK = "[ " + (format-color green "OK") + "  ]"
    $resERR = "[ " + (format-color red "ERR") + " ]"

    function new-host($hostname,$ipaddress) {
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
        
        $res = Invoke-RestMethod @params
        # instead of more complex records comparison or error handling, we're simply
        # going to look for conflict errors that tell us a record already exists.
        if ('conflict' -eq $res.errors.code) {
            $action = format-color red 'EXISTS'
            write-info ("[{0}] {1}`t{2}" -f $action, $hostname, $ipaddress)
        } else {
            $action = format-color green 'ADDED'
            foreach ($h in $res.data) {
                write-info ("[{0}] {1}`t{2}" -f $action, $h.content, $h.name)
            }
        }
    }

    $hosts = Get-Content $HostsFile |
        Select-String -NotMatch "^#|^$" |           # ignore blank lines and comments
        Select-String -NotMatch "^::1\b" |          # ignore ipv6 localhost
        Select-String -NotMatch "^127|^255" |       # ignore ipv4 localhost and broadcast
        Select-String -NotMatch "^ff"               # ignore ipv6 multicast entries
}

PROCESS {

    write-hr '='
    write-info "Adding NextDNS rewrite entries for $($hosts.Count) hosts entries."
    write-hr '-'
    foreach ($h in $hosts) {
        $hd = $h -split '\s+'
        new-host $hd[1] $hd[0]
    }
}