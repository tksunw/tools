#!/usr/bin/env powershell
<#

 Eric Ligman - Largest FREE Microsoft eBook Givaway!

 As seen at:
 	https://blogs.msdn.microsoft.com/mssmallbiz/2017/07/11/largest-free-microsoft-ebook-giveaway-im-giving-away-millions-of-free-microsoft-ebooks-again-including-windows-10-office-365-office-2016-power-bi-azure-windows-8-1-office-2013-sharepo/

 Link to download list of eBooks:
 	http://ligman.me/2tk1D2V

 Based on the script at:
 	https://msdnshared.blob.core.windows.net/media/2017/07/ELigman_DownloadAll_Powershell2.txt

##############################################################

 A little update and optimisation 14/07/2016

#>
[CmdletBinding()]

# Where do you want to download your books to?
$eBookDir = "$HOME/Dropbox/msbooks"

$ExtensionsToGet = @()
$ExtensionsToGet += '.MOBI'
#$ExtensionsToGet += '.EPUB'
#$ExtensionsToGet += '.PDF'

#
$hr = "-" * 80

function Get-Ebook {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$absuri,

        [Parameter(Mandatory=$True)]
        [String]$destfile,

        [Parameter(Mandatory=$True)]
        [String]$title 
    )

    $begin = Get-Date
    Write-Host -NoNewLine "Saving $title" 
    Invoke-WebRequest -Uri "$absuri" -Outfile "$destfile"
    $dtime = (New-Timespan -Start $begin -End (Get-Date)).TotalSeconds
    Write-Host "`t( $dtime seconds )"
    $script:downloadSecs += $dtime
}

Write-Host $hr
Write-Host "Downloading Free Microsoft E-Books"
Write-Host $hr

if (!(Test-Path $eBookDir)) {
    Write-Output "Book Directory $eBookDir not found.  Creating..."
    New-Item -ItemType Directory -Force -Path $eBookDir 
    Write-Host $hr
}

# Download the source list of books 
$downLoadList = "http://ligman.me/2tk1D2V"
$bookList = (Invoke-WebRequest $downLoadList).Content.Split("`n") | Select -Skip 1

$bookCount = $($bookList).Count
$downloadCount = 0
$downloadSecs = 0

foreach ($book in $bookList) { 
    try {
        $book
        $hdr = Invoke-WebRequest $book -Method Head 

        $absuri = $hdr.BaseResponse.RequestMessage.RequestURI.AbsoluteURI
        $title = [uri]::UnescapeDataString($hdr.BaseResponse.RequestMessage.RequestURI.Segments[-1])
        $saveTo = Join-Path $eBookDir $title
        if ($(Test-Path $saveTo) -eq $False) {
            if ($ExtensionsToGet -contains [IO.Path]::GetExtension($title)) {
                $downloadCount += 1
                Get-Ebook -absuri "$absuri" -destfile "$saveTo" -title "$title"
            }
        } 
    } catch {
        $book | Out-File $eBookDir"/dead_links.log" -Append
    }

    if ($downloadCount -eq 1) {
        break
    }
} 

$etime = [timespan]::fromseconds($downloadSecs)
$ftime = "{0:HH:mm:ss}" -f ([datetime]$etime.Ticks)
Write-Host $hr
Write-Output "Downloaded $downloadCount books in $ftime"
Write-Host $hr
