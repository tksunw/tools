# DiceWords Password Generator

`Get-DiceWords.ps1` generates Diceware-style passphrases using the EFF large wordlist.

## Features

- Cryptographically secure random number generation.
- Strict EFF wordlist structure validation (7,776 entries).
- Local trust-on-first-use (TOFU) hash tracking for managed wordlist downloads.
- Entropy and approximate combination count output.
- Optional complex password variant with special characters and digits (`-AddSpecialsAndNumbers`).
- Returns a `PSCustomObject` for pipeline/script use while displaying human-readable output.

## Usage

```powershell
pwsh ./DiceWords-Password-Generator/Get-DiceWords.ps1
```

Generate a stronger passphrase:

```powershell
pwsh ./DiceWords-Password-Generator/Get-DiceWords.ps1 -NumberofWords 6
```

Generate a complex password with special characters between words and two random digits appended:

```powershell
pwsh ./DiceWords-Password-Generator/Get-DiceWords.ps1 -NumberofWords 4 -AddSpecialsAndNumbers
```

Capture the result as an object in a script:

```powershell
$result = ./DiceWords-Password-Generator/Get-DiceWords.ps1 -NumberofWords 4 -AddSpecialsAndNumbers
$result.ComplexPassword
```

If the managed wordlist changes and you trust the new content:

```powershell
pwsh ./DiceWords-Password-Generator/Get-DiceWords.ps1 -AllowWordlistChange
```

## Output Object

The script returns a `PSCustomObject` with the following properties:

| Property | Description |
|---|---|
| `Words` | Title-cased words separated by spaces |
| `PassPhrase` | Words concatenated without spaces |
| `ComplexPassword` | Words joined by random special characters with two digits appended (only when `-AddSpecialsAndNumbers` is used) |
| `EntropyBits` | Bits of entropy for the passphrase |
| `Combinations` | Human-readable approximation of the combination space |

## Notes

- Default wordlist storage:
  - Windows: `%LOCALAPPDATA%\EFF\eff_large_wordlist.txt`
  - macOS: `$TMPDIR/EFF/eff_large_wordlist.txt`
  - Linux: `~/.local/share/EFF/eff_large_wordlist.txt`
- Trusted hash file is stored alongside the managed wordlist as `eff_large_wordlist.sha256`.
