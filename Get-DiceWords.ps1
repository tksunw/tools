<#
.SYNOPSIS
Rolls dice to Generate a password comprised of a specified number of words from a word list.

.DESCRIPTION
Using the EFF Large Word List, 5 simulated 6-sided Dice are "rolled" to generate a 5-digit number where each digit has a range
of 1-6.  Each "roll" provides a 5-digit number that corresponds to a word from the word list.  The specified number of words
are collected from the word list and outputed to STDOUT.

.INPUTS 
None

.OUTPUTS
String. Get-Dicewords returns a few sentences of text containing the dice words.

.NOTES
Use it as you will, under the terms of the MIT License (https://opensource.org/license/mit/)

.LINK
https://www.eff.org/deeplinks/2016/07/new-wordlists-random-passphrases

.LINK
https://opensource.org/license/mit/

#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false)]
    [Int]$NumberofWords = 2,

    [Parameter(Mandatory=$false)]
    [String]$WordListFile = "${env:LOCALAPPDATA}\EFF\eff_large_wordlist.txt"
)


# Using the EFF Large Wordlist from:
#    https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt
# for more info, see: 
#    https://www.eff.org/deeplinks/2016/07/new-wordlists-random-passphrases
$effWordlist = 'https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt'

# If we don't find the worklist in %LOCALAPPDATA%, then let's download it 
if (-not (Test-Path $WordListFile -ErrorAction SilentlyContinue)) {
    write-host -ForegroundColor Cyan 'WordlistFile not found, downloading EFF file'
    if (-not (Test-Path $env:LOCALAPPDATA\EFF)) {
        $null = New-Item -ItemType Directory -Path $env:LOCALAPPDATA\EFF -Force
    }
    $null = iwr $effWordlist -OutFile $WordListFile
}

# The second method is twice as fast.
# $wordlist = Get-Content $WordListFile | %{ $k, $v = -split $_ ; [PSCustomObject]@{ $key = $value }}
$wordlist = (Get-Content $WordListFile).replace("`t","=") | ConvertFrom-StringData 

# Get $NumberofWords 5-digit 6-sided dice rolls
$rolls    = @()
while($rolls.Count -lt $NumberofWords) {
    $roll = (1..6 | Get-Random -Count 5) -join ''
    # we definitely don't want the same word more than once, so filter...
    if ($rolls -notcontains $roll) {
        $rolls += $roll
    }
}

# Now, grab the words that correspond to the dice rolls from the wordlist. And 
# I like my words to be capitalized, because I think it looks nicer, and when the
# words are joined without delimiters, makes things more readable.
$dicewords  = ($rolls | ForEach-Object {[cultureinfo]::GetCultureInfo("en-US").TextInfo.ToTitleCase($wordlist.$_)}) -join ' '
$passphrase = $dicewords.replace(' ','')

"Your words are:"
$dicewords

"`nYour passphrase is:"
$passphrase

"`n# of possible passwords with $NumberofWords rolls:"
$poss = [BigInt]::Pow(7776, $NumberofWords)
if ($poss -gt [bigint]::pow(10, 27)) {
    "~ $($poss / [bigint]::pow(10, 27)) octillion"
} elseif ($poss -gt [bigint]::pow(10, 24)) {
    "~ $($poss / [bigint]::pow(10, 24)) septillion"
} elseif ($poss -gt [bigint]::pow(10, 21)) {
    "~ $($poss / [bigint]::pow(10, 21)) sextillion"
} elseif ($poss -gt [bigint]::pow(10, 18)) {
    "~ $($poss / [bigint]::pow(10, 18)) quintillion"
} elseif ($poss -gt [bigint]::pow(10, 15)) {
    "~ $($poss / [bigint]::pow(10, 15)) quadrillion"
} elseif ($poss -gt [bigint]::pow(10, 12)) {
    "~ $($poss / [bigint]::pow(10, 12)) trillion"
} elseif ($poss -gt [bigint]::pow(10, 9)) {
    "~ $($poss / [bigint]::pow(10, 9)) billion"
} elseif ($poss -gt [bigint]::pow(10, 6)) {
    "~ $($poss / [bigint]::pow(10, 6)) million"
} elseif ($poss -gt [bigint]::pow(10, 3)) {
    "~ $($poss / [bigint]::pow(10, 3)) thousand"
} else {
    "~ $poss"
} 

 
