<#
    .SYNOPSIS
        Generate an RFC 6238 compliant Time-based One Time Password.
 
    .DESCRIPTION
        This command computes a TOTP code based on a shared key,
        a timestamp, and the HMAC SHA-1, SHA-256, or SHA-512 
        algorithm, and truncated to a specified number of digits.
 
    .PARAMETER SecretKey 
        The secret key that you get from the 2FA/MFA verifier during MFA setup.
    
    .PARAMETER Interval
        The time-step value in SECONDS that defines the validity period.  
        The Default is 30 (SECONDS).

    .PARAMETER Digits
        The length of the code to generate. The Default is 6.

    .PARAMETER Algorithm
        The HMAC algorithm to use.  The Default is "SHA1".
        Also valid are "SHA256" and "SHA512"

    .INPUTS
        None.

    .OUTPUTS
        System.String. The one time password.
 
    .EXAMPLE
        PS C:\> Get-TOTPDigits -SecretKey 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
 
    .NOTES
        Author  : Tim Kennedy
        Date    : 2024-02-26
        License : MIT License
 
    .LINK
        https://tools.ietf.org/html/rfc6238
#>
[CmdletBinding()]
[Alias('tpin')]
Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$SecretKey,

    [Parameter(Mandatory=$false)]
    [ValidateRange(30,120)]
    [Int]$Interval = 30,

    [Parameter(Mandatory=$false)]
    [ValidateRange(5,9)]
    [Int]$Digits = 6,

    [Parameter(Mandatory=$false)]
    [ValidateSet('SHA1','SHA256','SHA512')]
    [String]$Algorithm = 'SHA1'
)

begin {
    # TOTP Shared Keys are Base32, which is A-Z + 2-7
    $BASE32CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'

    # Strip whitespace, hyphens, and padding then validate remaining characters
    $stripped = $SecretKey.ToUpper() -replace '[\s\-=]'
    # Don't keep the key in memory any longer than is necessary
    Remove-Variable SecretKey

    $invalidChars = $stripped -replace "[$BASE32CHARS]"
    if ($invalidChars.Length -gt 0) {
        $unique = ($invalidChars.ToCharArray() | Sort-Object -Unique) -join ''
        throw "SecretKey contains invalid Base32 characters: $unique"
    }

    $VALIDCHARS  = $stripped.GetEnumerator()
    Remove-Variable stripped

    # Seconds since the epoch to calculate the current interval
    $SECONDS     = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    # Instantiate a very large number that can later be
    # converted to a ByteArray. (per RFC needs to be bigger than Int32)
    $BIGINTEGER  = [Numerics.BigInteger]::Zero
}

Process {
    #TOTP values are calculated by the operation TOTP (K) = HOTP(K,C) = truncate(HMAC(K,C)) mod 10^d 
    foreach ($char in $VALIDCHARS) {
        $BIGINTEGER = ($BIGINTEGER -shl 5) -bor ($BASE32CHARS.IndexOf($char))
    }
    
    [byte[]]$keyBytes = $BIGINTEGER.ToByteArray()
    if ($keyBytes[-1] -eq 0) { $keyBytes = $keyBytes[0..($keyBytes.Length - 2)]}
    [Array]::Reverse($keyBytes)

    $intervals = [Convert]::ToInt64([Math]::Floor($SECONDS / $Interval))
    $intBytes  = [System.BitConverter]::GetBytes($intervals)
    if ([BitConverter]::IsLittleEndian) {[Array]::Reverse($intBytes) }

    $hmacAlgo  = "Security.Cryptography.HMAC${Algorithm}"
    $hmac      = $($hmacAlgo -as [Type])::new($keyBytes)
    try {
        $hash      = $hmac.ComputeHash($intBytes)
    }
    finally {
        $hmac.Dispose()
        [Array]::Clear($keyBytes, 0, $keyBytes.Length)
    }
    $offset    = $hash[$hash.Length-1] -band 0xF
    $fourBytes = $hash[$offset..($offset+3)]

    if ([BitConverter]::IsLittleEndian) {[Array]::Reverse($fourBytes) }
    $bandBytes = ([BitConverter]::ToInt32($fourBytes, 0) -band 0x7FFFFFFF)

    $modulus   = [int][math]::pow(10, $Digits)
    $rawPin    = $bandBytes % $modulus

    # pad with leading zeros to $Digits of length if needed
    "{0:D${Digits}}" -f [int]$rawPin
}
