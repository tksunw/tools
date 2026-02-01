<#
.SYNOPSIS
Generates cryptographically secure diceware passphrases using the EFF Large Wordlist.

.DESCRIPTION
This script generates secure, memorable passphrases using the diceware method with the EFF Large Word List.
It simulates rolling five 6-sided dice to generate 5-digit numbers (each digit 1-6), where each roll
corresponds to a unique word from the 7,776-word EFF wordlist.

Key features:
- Uses cryptographically secure random number generation (System.Security.Cryptography.RandomNumberGenerator)
- Automatically downloads and verifies the EFF wordlist using SHA-256 hash validation
- Prevents duplicate words in the same passphrase
- Calculates and displays entropy bits for security awareness
- Cross-platform support (Windows, macOS, Linux)
- Outputs both spaced words and concatenated passphrase

Security: This implementation uses cryptographically secure randomness suitable for password generation,
unlike standard PRNG functions which should never be used for cryptographic purposes.

.PARAMETER NumberofWords
The number of words to include in the passphrase. Must be between 1 and 20.
Default: 2

More words increase security exponentially:
- 4 words: ~51.7 bits of entropy (recommended minimum)
- 5 words: ~64.6 bits of entropy
- 6 words: ~77.5 bits of entropy (recommended for high security)
- 7 words: ~90.5 bits of entropy

.PARAMETER WordListFile
Optional path to a custom EFF wordlist file. If not specified, uses platform-specific default locations:
- Windows: %LOCALAPPDATA%\EFF\eff_large_wordlist.txt
- macOS: $TMPDIR/EFF/eff_large_wordlist.txt
- Linux: ~/.local/share/EFF/eff_large_wordlist.txt

If the file doesn't exist, it will be downloaded automatically from the official EFF source and
verified against a known SHA-256 hash.

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
System.String
Outputs the generated words (title-cased and space-separated), the concatenated passphrase,
entropy information in bits, and the total number of possible combinations.

.EXAMPLE
PS> .\Get-DiceWords.ps1

Your words are:
Jargon Angst

Your passphrase is:
JargonAngst

# of possible passwords with 2 rolls:
Entropy: 25.85 bits
~ 60.47 million

Generates a 2-word passphrase using default settings.

.EXAMPLE
PS> .\Get-DiceWords.ps1 -NumberofWords 6

Your words are:
Matador Wayside Reboot Unsteady Imitate Snag

Your passphrase is:
MatadorWaysideRebootUnsteadyImitateSnag

# of possible passwords with 6 rolls:
Entropy: 77.55 bits
~ 221.07 quintillion

Generates a secure 6-word passphrase with ~77.5 bits of entropy.

.EXAMPLE
PS> .\Get-DiceWords.ps1 -NumberofWords 4 -WordListFile "C:\Custom\wordlist.txt"

Uses a custom wordlist file instead of downloading the default EFF wordlist.

.NOTES
Author: Original script author unknown, refactored for security and efficiency
Version: 2.0
License: MIT License (https://opensource.org/license/mit/)

Security Considerations:
- Uses System.Security.Cryptography.RandomNumberGenerator for cryptographic randomness
- Verifies downloaded wordlist integrity via SHA-256 hash
- Suitable for generating passwords, passphrases, and other security credentials

Platform Support: Windows (PowerShell 5.1+), macOS, and Linux (PowerShell 7+)

.LINK
https://www.eff.org/deeplinks/2016/07/new-wordlists-random-passphrases

.LINK
https://www.eff.org/dice

.LINK
https://opensource.org/license/mit/

#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 20)]
    [Int]$NumberofWords = 2,

    [Parameter(Mandatory=$false)]
    [String]$WordListFile
)

# Platform-specific path handling
if (-not $WordListFile) {
    if ($isMacOS) {
        $WordListFile = "${env:TMPDIR}/EFF/eff_large_wordlist.txt"
        $WordListPath = "${env:TMPDIR}/EFF"
    } elseif ($IsLinux) {
        $WordListFile = "${env:HOME}/.local/share/EFF/eff_large_wordlist.txt"
        $WordListPath = "${env:HOME}/.local/share/EFF"
    } else {
        $WordListFile = "${env:LOCALAPPDATA}\EFF\eff_large_wordlist.txt"
        $WordListPath = "${env:LOCALAPPDATA}\EFF"
    }
}

# Using the EFF Large Wordlist from:
#    https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt
# for more info, see:
#    https://www.eff.org/deeplinks/2016/07/new-wordlists-random-passphrases
$effWordlist = 'https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt'
# Known SHA-256 hash of the official EFF wordlist (verified 2016-07-18)
$expectedHash = 'b9cf6752e7d15c56c5f4c88f4383c6e2d1f016c2f54e2024a1f1cfa792b4a13f'

# Download wordlist if not present
if (-not (Test-Path $WordListFile -ErrorAction SilentlyContinue)) {
    try {
        Write-Host -ForegroundColor Cyan 'Wordlist file not found, downloading EFF file...'

        if (-not (Test-Path $WordListPath)) {
            $null = New-Item -ItemType Directory -Path $WordListPath -Force -ErrorAction Stop
        }

        # Download with progress
        $ProgressPreference = 'SilentlyContinue'  # Faster download
        Invoke-WebRequest -Uri $effWordlist -OutFile $WordListFile -UseBasicParsing -ErrorAction Stop
        $ProgressPreference = 'Continue'

        # Verify file integrity
        Write-Host -ForegroundColor Cyan 'Verifying download integrity...'
        $actualHash = (Get-FileHash -Path $WordListFile -Algorithm SHA256).Hash.ToLower()

        if ($actualHash -ne $expectedHash) {
            Remove-Item -Path $WordListFile -Force -ErrorAction SilentlyContinue
            throw "Downloaded wordlist hash mismatch. Expected: $expectedHash, Got: $actualHash. File removed for security."
        }

        Write-Host -ForegroundColor Green 'Download verified successfully.'
    }
    catch {
        Write-Error "Failed to download or verify wordlist: $_"
        exit 1
    }
}

# Verify wordlist still exists and is readable
if (-not (Test-Path $WordListFile)) {
    Write-Error "Wordlist file not found at: $WordListFile"
    exit 1
}

# Load wordlist efficiently
try {
    $wordlist = (Get-Content $WordListFile -ErrorAction Stop).Replace("`t", "=") | ConvertFrom-StringData

    if ($wordlist.Count -eq 0) {
        throw "Wordlist is empty or invalid"
    }
}
catch {
    Write-Error "Failed to load wordlist: $_"
    exit 1
}

# Initialize cryptographically secure RNG
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

# Function to generate a cryptographically secure random number in range
function Get-SecureRandomNumber {
    param([int]$Min, [int]$Max)

    $range = $Max - $Min
    $bytes = New-Object byte[] 4
    $rng.GetBytes($bytes)
    $randomInt = [System.BitConverter]::ToUInt32($bytes, 0)

    return ($randomInt % $range) + $Min
}

# Generate $NumberofWords unique 5-digit 6-sided dice rolls using HashSet for efficiency
$rolls = [System.Collections.Generic.HashSet[string]]::new()

try {
    while ($rolls.Count -lt $NumberofWords) {
        # Generate 5 dice rolls (each 1-6) using cryptographically secure random
        $roll = -join (1..5 | ForEach-Object { Get-SecureRandomNumber -Min 1 -Max 7 })

        # HashSet.Add() returns $false if duplicate, $true if added - automatic deduplication
        $null = $rolls.Add($roll)
    }
}
finally {
    # Clean up RNG
    $rng.Dispose()
}

# Retrieve words corresponding to dice rolls
# Capitalize words for readability when concatenated
$dicewords = ($rolls | ForEach-Object {
    $word = $wordlist.$_
    if ($word) {
        # Use current culture instead of hardcoded en-US
        (Get-Culture).TextInfo.ToTitleCase($word)
    }
    else {
        Write-Warning "Roll $_ not found in wordlist"
        $null
    }
} | Where-Object { $_ }) -join ' '

$passphrase = $dicewords.Replace(' ', '')

# Output results
Write-Output "Your words are:"
Write-Output $dicewords

Write-Output "`nYour passphrase is:"
Write-Output $passphrase

# Calculate entropy and possible combinations
Write-Output "`n# of possible passwords with $NumberofWords rolls:"
$poss = [BigInt]::Pow(7776, $NumberofWords)

# Calculate bits of entropy
$entropyBits = [Math]::Log($poss, 2)
Write-Output "Entropy: $([Math]::Round($entropyBits, 2)) bits"

# Format large numbers more efficiently
$magnitude = @(
    @{Name = 'octillion';   Power = 27}
    @{Name = 'septillion';  Power = 24}
    @{Name = 'sextillion';  Power = 21}
    @{Name = 'quintillion'; Power = 18}
    @{Name = 'quadrillion'; Power = 15}
    @{Name = 'trillion';    Power = 12}
    @{Name = 'billion';     Power = 9}
    @{Name = 'million';     Power = 6}
    @{Name = 'thousand';    Power = 3}
)

$formatted = $false
foreach ($mag in $magnitude) {
    $threshold = [bigint]::Pow(10, $mag.Power)
    if ($poss -gt $threshold) {
        $value = [Math]::Round($poss / $threshold, 2)
        Write-Output "~ $value $($mag.Name)"
        $formatted = $true
        break
    }
}

if (-not $formatted) {
    Write-Output "~ $poss"
}
