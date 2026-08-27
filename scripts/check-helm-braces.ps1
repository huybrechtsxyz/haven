<#
.SYNOPSIS
    Fails if any local Helm chart template contains spaced-out Go-template
    braces (`{ {` / `} }`) instead of the required literal `{{` / `}}`.

.DESCRIPTION
    Some automated formatting step in this environment has repeatedly
    inserted a stray space into Helm Go-template braces, turning
    `{{ .Values.x }}` into `{ { .Values.x } }`. YAML then parses the
    unprocessed braces as a flow mapping instead of leaving them as literal
    text for Helm to render, so `helm lint` / `helm template` fail with
    errors like:

        invalid map key: map[interface {}]interface {}{".Values.x":interface {}(nil)}

    Run this before committing/deploying any local Helm chart
    (services/**/templates/*.yaml) to catch the corruption early.

.PARAMETER Path
    Root directory to scan recursively for chart template files. Defaults
    to 'services'.

.EXAMPLE
    ./scripts/check-helm-braces.ps1
#>
[CmdletBinding()]
param(
    [string]$Path = "services"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scanRoot = Resolve-Path (Join-Path $repoRoot $Path)

$templateFiles = Get-ChildItem -Path $scanRoot -Recurse -Filter "*.yaml" |
Where-Object { $_.FullName -match '[\\/]templates[\\/]' }

$pattern = '\{\s+\{|\}\s+\}'
$failures = @()

foreach ($file in $templateFiles) {
    $lines = Get-Content -Path $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) {
            $relativePath = $file.FullName.Substring($repoRoot.Length + 1)
            $failures += [PSCustomObject]@{
                File = $relativePath
                Line = $i + 1
                Text = $lines[$i].Trim()
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Found spaced Go-template braces (should be '{{'/'}}', not '{ {' / '} }'):" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host ("  {0}:{1}: {2}" -f $failure.File, $failure.Line, $failure.Text) -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Fix: replace '{ {' with '{{' and '} }' with '}}' in the files above." -ForegroundColor Yellow
    exit 1
}

Write-Host "OK: no spaced Go-template braces found in $($templateFiles.Count) template file(s) under '$Path'." -ForegroundColor Green
exit 0
