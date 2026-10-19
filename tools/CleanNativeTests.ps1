$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$verificationRoot = Join-Path $projectRoot 'verification'
$copyParent = 'M:\SteamLibrary\steamapps\common\_ftn_coop_native_tests'
$cleaned = 0
foreach ($run in @(Get-ChildItem -LiteralPath $verificationRoot -Directory -Filter 'native-network-*')) {
    $requestPath = Join-Path $run.FullName 'request.json'
    if (-not (Test-Path -LiteralPath $requestPath)) { continue }
    $request = Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json
    # Older shared-profile diagnostics did not record isolated copy ownership.
    if (-not $request.game_copies) { continue }
    $runId = [string]$request.run_id
    if ($runId -notmatch '^[0-9a-f]{32}$') { throw 'Invalid owned run ID.' }
    $expectedCopy = [IO.Path]::GetFullPath((Join-Path $copyParent $runId))
    if ([IO.Path]::GetFullPath([string]$request.game_copies) -ne $expectedCopy) { throw 'Copy directory does not match owned run.' }
    $active = @(Get-Process -Name FindTheNeedle -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($expectedCopy+'\',[StringComparison]::OrdinalIgnoreCase) })
    if ($active.Count -gt 0) { Write-Output ('Still running, retained: '+$runId); continue }
    $targets = @($expectedCopy)
    foreach ($profile in $request.private_profiles) {
        $profilePath = [IO.Path]::GetFullPath([string]$profile)
        $profileParent = Split-Path -Parent $profilePath
        $profileName = Split-Path -Leaf $profilePath
        if ($profileParent -ne [IO.Path]::GetFullPath($env:APPDATA) -or $profileName -notmatch ('^FTN-Coop-Native-'+$runId+'-[0-3]$')) { throw 'Profile directory does not match owned run.' }
        $targets += $profilePath
    }
    foreach ($target in $targets) {
        if (-not (Test-Path -LiteralPath $target)) { continue }
        $resolvedTarget = (Resolve-Path -LiteralPath $target).Path.TrimEnd('\')
        if ($resolvedTarget -ne $target) { throw 'Resolved cleanup target differs from validated owned directory.' }
        Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
    }
    $cleaned += 1
}
Write-Output ('Cleaned owned native test folders; reports retained. Runs: '+$cleaned)
