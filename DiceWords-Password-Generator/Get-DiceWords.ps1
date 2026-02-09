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

.PARAMETER AddSpecialsAndNumbers
When specified, generates a complex password variant by replacing each space between words with a
random special character and appending two random digits. Uses cryptographically secure randomness.

.PARAMETER WordListFile
Optional path to a custom EFF wordlist file. If not specified, uses platform-specific default locations:
- Windows: %LOCALAPPDATA%\EFF\eff_large_wordlist.txt
- macOS: $TMPDIR/EFF/eff_large_wordlist.txt
- Linux: ~/.local/share/EFF/eff_large_wordlist.txt

If the file doesn't exist, it will be downloaded automatically from the official EFF source and
validated for expected diceware structure.

.PARAMETER AllowWordlistChange
When using the default managed wordlist path, this switch allows updating the locally trusted
SHA-256 hash if the downloaded wordlist content changes in the future.

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
PSCustomObject
Returns an object with properties: Words, PassPhrase, ComplexPassword, EntropyBits, Combinations.
Also displays the generated words, passphrase, entropy, and (if -AddSpecialsAndNumbers) the complex password.

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
PS> .\Get-DiceWords.ps1 -NumberofWords 4 -AddSpecialsAndNumbers

Your words are:
Matador Wayside Reboot Unsteady

Your passphrase is:
MatadorWaysideRebootUnsteady

Your complex password is:
Matador^Wayside$Reboot_Unsteady37

Generates a 4-word passphrase plus a complex variant with special characters and digits.

.EXAMPLE
PS> .\Get-DiceWords.ps1 -NumberofWords 4 -WordListFile "C:\Custom\wordlist.txt"

Uses a custom wordlist file instead of downloading the default EFF wordlist.

.NOTES
Author: Original script author unknown, refactored for security and efficiency
Version: 2.0
License: MIT License (https://opensource.org/license/mit/)

Security Considerations:
- Uses System.Security.Cryptography.RandomNumberGenerator for cryptographic randomness
- Validates downloaded wordlist structure (7,776 unique 1-6 keys with non-empty words)
- Uses local trust-on-first-use (TOFU) hash tracking for unexpected wordlist changes
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
    [switch]$AddSpecialsAndNumbers,

    [Parameter(Mandatory=$false)]
    [String]$WordListFile,

    [Parameter(Mandatory=$false)]
    [switch]$AllowWordlistChange
)

# Platform-specific path handling
$usingDefaultWordList = -not $PSBoundParameters.ContainsKey('WordListFile')
if (-not $WordListFile) {
    if ($isMacOS) {
        $WordListFile = "${env:TMPDIR}/EFF/eff_large_wordlist.txt"
    } elseif ($IsLinux) {
        $WordListFile = "${env:HOME}/.local/share/EFF/eff_large_wordlist.txt"
    } else {
        $WordListFile = "${env:LOCALAPPDATA}\EFF\eff_large_wordlist.txt"
    }
}
$WordListPath = Split-Path -Path $WordListFile -Parent
if ([string]::IsNullOrWhiteSpace($WordListPath)) {
    $WordListPath = '.'
}
$TrustedHashFile = Join-Path -Path $WordListPath -ChildPath 'eff_large_wordlist.sha256'
$expectedEntryCount = 7776

# Using the EFF Large Wordlist from:
#    https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt
# for more info, see:
#    https://www.eff.org/deeplinks/2016/07/new-wordlists-random-passphrases
$effWordlist = 'https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt'
function Get-WordListHash {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Assert-TrustedWordListHash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TrustedHashPath,
        [Parameter(Mandatory = $true)][switch]$AllowChange
    )

    $currentHash = Get-WordListHash -Path $Path

    if (-not (Test-Path -Path $TrustedHashPath -PathType Leaf -ErrorAction SilentlyContinue)) {
        Set-Content -Path $TrustedHashPath -Value $currentHash -Encoding Ascii -NoNewline -ErrorAction Stop
        Write-Verbose "Initialized trusted hash at: $TrustedHashPath"
        return
    }

    $trustedHash = ((Get-Content -Path $TrustedHashPath -ErrorAction Stop | Select-Object -First 1).Trim()).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($trustedHash)) {
        throw "Trusted hash file '$TrustedHashPath' is empty or invalid."
    }

    if ($trustedHash -ne $currentHash) {
        $message = "Wordlist hash changed. Trusted: $trustedHash Current: $currentHash"
        if ($AllowChange) {
            Write-Warning "$message. Updating trusted hash because -AllowWordlistChange was specified."
            Set-Content -Path $TrustedHashPath -Value $currentHash -Encoding Ascii -NoNewline -ErrorAction Stop
        } else {
            throw "$message. Re-run with -AllowWordlistChange to trust the new wordlist hash."
        }
    }
}

function Get-ValidatedWordList {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$ExpectedCount
    )

    $wordlist = @{}
    $lineNumber = 0

    foreach ($line in (Get-Content -Path $Path -ErrorAction Stop)) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) {
            throw "Invalid wordlist: blank line at line $lineNumber."
        }

        $parts = $line -split "`t", 2
        if ($parts.Count -ne 2) {
            throw "Invalid wordlist: expected tab-delimited key/value at line $lineNumber."
        }

        $key = $parts[0].Trim()
        $word = $parts[1].Trim()

        if ($key -notmatch '^[1-6]{5}$') {
            throw "Invalid wordlist: key '$key' at line $lineNumber is not a 5-digit dice code using digits 1-6."
        }

        if ([string]::IsNullOrWhiteSpace($word)) {
            throw "Invalid wordlist: empty word at line $lineNumber."
        }

        if ($wordlist.ContainsKey($key)) {
            throw "Invalid wordlist: duplicate key '$key' at line $lineNumber."
        }

        $wordlist[$key] = $word
    }

    if ($wordlist.Count -ne $ExpectedCount) {
        throw "Invalid wordlist: expected $ExpectedCount entries, found $($wordlist.Count)."
    }

    return $wordlist
}

# Download wordlist if not present
if (-not (Test-Path $WordListFile -ErrorAction SilentlyContinue)) {
    try {
        Write-Verbose 'Wordlist file not found, downloading EFF file...'

        if (-not (Test-Path -Path $WordListPath -PathType Container -ErrorAction SilentlyContinue)) {
            $null = New-Item -ItemType Directory -Path $WordListPath -Force -ErrorAction Stop
        }

        # Download with progress
        $originalProgressPreference = $ProgressPreference
        try {
            $ProgressPreference = 'SilentlyContinue'  # Faster download
            Invoke-WebRequest -Uri $effWordlist -OutFile $WordListFile -UseBasicParsing -ErrorAction Stop
        }
        finally {
            $ProgressPreference = $originalProgressPreference
        }
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
    # Validate structure first to ensure a tampered/corrupt file is rejected.
    $wordlist = Get-ValidatedWordList -Path $WordListFile -ExpectedCount $expectedEntryCount

    # Trust On First Use (TOFU): persist a local trusted hash and detect unexpected changes later.
    if ($usingDefaultWordList) {
        Assert-TrustedWordListHash -Path $WordListFile -TrustedHashPath $TrustedHashFile -AllowChange:$AllowWordlistChange
    }
}
catch {
    Write-Error "Failed to load wordlist: $_"
    exit 1
}

# Function to generate a cryptographically secure random number in range
function Get-SecureRandomNumber {
    param([int]$Min, [int]$Max)
    return [System.Security.Cryptography.RandomNumberGenerator]::GetInt32($Min, $Max)
}

# Generate $NumberofWords unique 5-digit 6-sided dice rolls using HashSet for efficiency
$rolls = [System.Collections.Generic.HashSet[string]]::new()

while ($rolls.Count -lt $NumberofWords) {
    # Generate 5 dice rolls (each 1-6) using cryptographically secure random
    $roll = -join (1..5 | ForEach-Object { Get-SecureRandomNumber -Min 1 -Max 7 })

    # HashSet.Add() returns $false if duplicate, $true if added - automatic deduplication
    $null = $rolls.Add($roll)
}

# Retrieve words corresponding to dice rolls
# Capitalize words for readability when concatenated
$textInfo = (Get-Culture).TextInfo
$dicewords = ($rolls | ForEach-Object {
    $word = $wordlist.$_
    if ($word) {
        $textInfo.ToTitleCase($word)
    }
    else {
        Write-Warning "Roll $_ not found in wordlist"
        $null
    }
} | Where-Object { $_ }) -join ' '

$passphrase = $dicewords.Replace(' ', '')

# Generate complex password if requested
$specialChars = @('~','!','@','#','$','%','^','&','*','_','-','+','=','`','|','\','(',')','{','}','[',']',':',';','"',"'",'<','>',',','.','?','/')
$numbers      = @('0','1','2','3','4','5','6','7','8','9')
$complexPassword = $null

if ($AddSpecialsAndNumbers) {
    $complexPassword = $dicewords
    [regex]$pattern = ' '
    while ($complexPassword -match ' ') {
        $specialChar = $specialChars[(Get-SecureRandomNumber -Min 0 -Max $specialChars.Count)]
        $complexPassword = $pattern.Replace($complexPassword, $specialChar, 1)
    }
    $digit1 = $numbers[(Get-SecureRandomNumber -Min 0 -Max $numbers.Count)]
    $digit2 = $numbers[(Get-SecureRandomNumber -Min 0 -Max $numbers.Count)]
    $complexPassword = $complexPassword + $digit1 + $digit2
}

# Display results
Write-Host "Your words are:"
Write-Host $dicewords

Write-Host "`nYour passphrase is:"
Write-Host $passphrase

if ($complexPassword) {
    Write-Host "`nYour complex password is:"
    Write-Host $complexPassword
}

# Calculate entropy and possible combinations
$poss = [bigint]1
for ($i = 0; $i -lt $NumberofWords; $i++) {
    $poss *= (7776 - $i)
}

# Calculate bits of entropy
$entropyBits = [Math]::Round([Math]::Log([double]$poss, 2), 2)

Write-Host "`n# of possible passwords with $NumberofWords unique rolls:"
Write-Host "Entropy: $entropyBits bits"

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

$combinationsText = $null
foreach ($mag in $magnitude) {
    $threshold = [bigint]::Pow(10, $mag.Power)
    if ($poss -gt $threshold) {
        $value = [Math]::Round(([double]$poss / [double]$threshold), 2)
        $combinationsText = "~ $value $($mag.Name)"
        break
    }
}
if (-not $combinationsText) {
    $combinationsText = "~ $poss"
}
Write-Host $combinationsText

# Return structured object for pipeline/script use
[PSCustomObject]@{
    Words           = $dicewords
    PassPhrase      = $passphrase
    ComplexPassword  = $complexPassword
    EntropyBits     = $entropyBits
    Combinations    = $combinationsText
}
