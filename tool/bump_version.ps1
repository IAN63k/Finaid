<#
.SYNOPSIS
  Sets `version:` in pubspec.yaml to the given semver and increments the build number (+N).
.EXAMPLE
  tool\bump_version.ps1 0.2.0
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Version,
    [Parameter(Position = 1)][string]$Pubspec = (Join-Path $PSScriptRoot "..\pubspec.yaml")
)
$ErrorActionPreference = "Stop"

if ($Version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') {
    Write-Host "error: version must be MAJOR.MINOR.PATCH (got '$Version')" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $Pubspec)) {
    Write-Host "error: pubspec not found: $Pubspec" -ForegroundColor Red
    exit 1
}

$content = [System.IO.File]::ReadAllText($Pubspec)
$pattern = '(?m)^version:[ \t]*(\d+\.\d+\.\d+)(?:\+(\d+))?[ \t]*\r?$'
$m = [regex]::Match($content, $pattern)
if (-not $m.Success) {
    Write-Host "error: no 'version: X.Y.Z[+N]' line found in $Pubspec" -ForegroundColor Red
    exit 1
}

$old = $m.Groups[1].Value
if ($m.Groups[2].Success) { $old += "+" + $m.Groups[2].Value }
$build = if ($m.Groups[2].Success) { [int]$m.Groups[2].Value + 1 } else { 1 }
$newFull = "$Version+$build"

# Replace only the first match, normalize to LF, write UTF-8 without BOM.
$updated = [regex]::new($pattern).Replace($content, "version: $newFull", 1)
$updated = $updated -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($Pubspec, $updated, [System.Text.UTF8Encoding]::new($false))

Write-Host "pubspec.yaml: $old -> $newFull"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  git add pubspec.yaml CHANGELOG.md"
Write-Host "  git commit -m `"chore(release): v$Version`""
Write-Host "  git tag -a v$Version -m `"Finaid v$Version`""
Write-Host "  git push --follow-tags"
