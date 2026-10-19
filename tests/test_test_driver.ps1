$ErrorActionPreference = 'Stop'
$driver = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\Test.ps1'
& $driver -TestScript 'res://tests/fixtures/runtime_error.gd' *> $null
if ($LASTEXITCODE -eq 0) {
    throw 'The test driver reported success despite a GDScript runtime error.'
}
Write-Output 'PASS test_driver_detects_runtime_errors'
exit 0
