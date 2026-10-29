param(
    [ValidateSet(2,4)][int]$Players = 2,
    [string]$GameDir = 'M:\SteamLibrary\steamapps\common\Find The Needle Demo',
    [switch]$Presence,
    [switch]$Persistence,
    [ValidateRange(0,45)][int]$ReviewSeconds = 0,
    [string]$SaveFile = '',
    [ValidateRange(0,300)][int]$PerformanceSeconds = 0,
    [switch]$Headless,
    [ValidateRange(-1,3)][int]$GraphicalPeer = -1,
    [string]$ModSource = ''
)
$ErrorActionPreference = 'Stop'
if ($Headless -and $Presence) { throw 'Presence checks inspect native draw nodes and require a graphical runtime. Omit -Headless.' }
if ($GraphicalPeer -ge 0 -and (-not $Headless -or $GraphicalPeer -ge $Players -or $PerformanceSeconds -lt 30)) { throw 'GraphicalPeer requires a valid peer index, -Headless and a performance scenario.' }
$workspaceRoot = Split-Path -Parent $PSScriptRoot
if ($ModSource -eq '') { $ModSource = Join-Path $workspaceRoot 'mods\ftn_coop' }
if (-not (Test-Path -LiteralPath (Join-Path $ModSource 'bootstrap.gd') -PathType Leaf)) { throw 'Missing mod source.' }
$resolvedGameDir = (Resolve-Path -LiteralPath $GameDir).ProviderPath
$nativeManifestPath = Join-Path (Split-Path -Parent (Split-Path -Parent $resolvedGameDir)) 'appmanifest_5165210.acf'
if (-not (Test-Path -LiteralPath $nativeManifestPath -PathType Leaf)) { throw 'Native testing requires the source Steam installation manifest.' }
$nativeManifest = [IO.File]::ReadAllText($nativeManifestPath)
$nativeAppId = [regex]::Match($nativeManifest,'"appid"\s+"([0-9]+)"').Groups[1].Value
$nativeInstallDir = [regex]::Match($nativeManifest,'"installdir"\s+"([^"/\\]+)"').Groups[1].Value
$nativeGameBuild = [regex]::Match($nativeManifest,'"buildid"\s+"([0-9]+)"').Groups[1].Value
if ($nativeAppId -ne '5165210' -or $nativeInstallDir -ne (Split-Path -Leaf $resolvedGameDir) -or -not $nativeGameBuild) { throw 'Source Steam manifest does not identify this demo installation.' }
if ($PerformanceSeconds -gt 0 -and ($PerformanceSeconds -lt 30 -or -not (Test-Path -LiteralPath $SaveFile -PathType Leaf))) { throw 'Performance testing requires at least 30 seconds and an existing save copy.' }
$nativeRunId = [guid]::NewGuid().ToString('N')
$nativePort = Get-Random -Minimum 24000 -Maximum 44000
$nativeLogDir = Join-Path $workspaceRoot ('verification\native-network-' + $Players + '-' + $nativeRunId)
$nativeWorkingLogDir = if ($PerformanceSeconds -gt 0) { Join-Path $env:LOCALAPPDATA ('FTN-Coop\Tests\'+$nativeRunId) } else { $nativeLogDir }
$gameUserRoot = Join-Path $env:APPDATA 'Godot\app_userdata\Haystack Incremental'
$nativeReportDir = Join-Path $nativeWorkingLogDir 'reports'
$nativeCopyBase = Join-Path (Split-Path -Parent $resolvedGameDir) '_ftn_coop_native_tests'
$nativeCopyRunRoot = Join-Path $nativeCopyBase $nativeRunId
$privateUserRoots = @()
$nativeSourceHashes = @{}
Get-ChildItem -LiteralPath $ModSource -Filter '*.gd' -File | ForEach-Object { $nativeSourceHashes[$_.Name] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
New-Item -Path $nativeLogDir -ItemType Directory -Force | Out-Null
New-Item -Path $nativeReportDir -ItemType Directory -Force | Out-Null
$nativeNames = @('host') + @(1..($Players-1) | ForEach-Object { 'guest-' + $_ })
$nativeProcesses = @()
$nativeLogPaths = @()
$nativeHeadlessPeers = @()
$nativeGraphicalPeers = @()

function Read-NativeReport([string]$ReportName) {
    $reportPath = Join-Path $nativeReportDir ($ReportName + '.json')
    if (-not (Test-Path -LiteralPath $reportPath)) { return $null }
    try { return (Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json) }
    catch { return $null } # A writer may be replacing its own report this frame.
}

function Test-NativeAgreement($Reports) {
    $nativeHostReport = $Reports['host']
    if ($null -eq $nativeHostReport) { return @{ ok=$false; mismatch=$false; counts=@{} } }
    $matchingCounts = @{}
    foreach ($reportName in $nativeNames | Where-Object { $_ -ne 'host' }) {
        $guestReport = $Reports[$reportName]
        if ($null -eq $guestReport) { return @{ ok=$false; mismatch=$false; counts=$matchingCounts } }
        $matching = 0
        $afterScenario = 0
        foreach ($entry in $guestReport.history.PSObject.Properties) {
            $expected = $nativeHostReport.history.PSObject.Properties[$entry.Name]
            if ($null -eq $expected) { continue }
            if ($entry.Value -ne $expected.Value) {
                return @{ ok=$false; mismatch=$true; peer=$reportName; revision=$entry.Name; counts=$matchingCounts }
            }
            $matching++
            if ($null -ne $nativeHostReport.scenario_revision -and $nativeHostReport.scenario_revision -ge 0 -and [int]$entry.Name -ge $nativeHostReport.scenario_revision) { $afterScenario++ }
        }
        $matchingCounts[$reportName] = $matching
        if ($matching -lt 3 -or $afterScenario -lt 1) { return @{ ok=$false; mismatch=$false; counts=$matchingCounts } }
    }
    return @{ ok=$true; mismatch=$false; counts=$matchingCounts }
}

$previousTestOutput = [Environment]::GetEnvironmentVariable('FTN_COOP_TEST_OUTPUT','Process')
[Environment]::SetEnvironmentVariable('FTN_COOP_TEST_OUTPUT',$nativeReportDir.Replace('\','/'),'Process')
try {
for ($nativeIndex=0; $nativeIndex -lt $Players; $nativeIndex++) {
    $peerHeadless = $Headless -and ($nativeIndex -ne $GraphicalPeer)
    if ($peerHeadless) { $nativeHeadlessPeers += $nativeIndex } else { $nativeGraphicalPeers += $nativeIndex }
    $privateGameDir = Join-Path $nativeCopyRunRoot $nativeIndex
    New-Item -Path $privateGameDir -ItemType Directory -Force | Out-Null
    foreach ($nativeFile in Get-ChildItem -LiteralPath $resolvedGameDir -File | Where-Object { $_.Extension -in @('.exe','.pck','.dll','.txt') }) {
        $targetFile = Join-Path $privateGameDir $nativeFile.Name
        try { New-Item -Path $targetFile -ItemType HardLink -Value $nativeFile.FullName -ErrorAction Stop | Out-Null }
        catch { Copy-Item -LiteralPath $nativeFile.FullName -Destination $targetFile }
    }
    $privateModDir = Join-Path $privateGameDir 'mods\ftn_coop'
    New-Item -Path $privateModDir -ItemType Directory -Force | Out-Null
    Get-ChildItem -LiteralPath $ModSource -Filter '*.gd' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $privateModDir }
    if ($PerformanceSeconds -gt 0) {
        Copy-Item -LiteralPath (Join-Path $privateModDir 'network_controller.gd') -Destination (Join-Path $privateModDir 'network_controller_base.gd')
        Copy-Item -LiteralPath (Join-Path $workspaceRoot 'tests\native_performance_network.gd') -Destination (Join-Path $privateModDir 'network_controller.gd')
        Copy-Item -LiteralPath (Join-Path $workspaceRoot 'tests\native_performance_adapter.gd') -Destination (Join-Path $privateModDir 'performance_adapter.gd')
        Copy-Item -LiteralPath (Join-Path $privateModDir 'native_network_check.gd') -Destination (Join-Path $privateModDir 'native_integrity_check.gd')
        Copy-Item -LiteralPath (Join-Path $workspaceRoot 'tests\native_performance_check.gd') -Destination (Join-Path $privateModDir 'native_network_check.gd')
        Copy-Item -LiteralPath (Join-Path $workspaceRoot 'tests\native_render_witness.gd') -Destination (Join-Path $privateModDir 'native_render_witness.gd')
        if ($nativeIndex -eq 0) { Copy-Item -LiteralPath $SaveFile -Destination (Join-Path $privateGameDir 'performance-slot.dat') }
    }
    $privateUserName = 'FTN-Coop-Native-' + $nativeRunId + '-' + $nativeIndex
    $privateUserRoot = Join-Path $env:APPDATA $privateUserName
    $privateUserRoots += $privateUserRoot
    New-Item -Path $privateUserRoot -ItemType Directory -Force | Out-Null
    $originalShaderCache = Join-Path $gameUserRoot 'shader_cache'
    if (-not $peerHeadless -and (Test-Path -LiteralPath $originalShaderCache)) { Copy-Item -LiteralPath $originalShaderCache -Destination $privateUserRoot -Recurse }
    $testOverride = "[autoload]`nFtnCoop=`"*mods/ftn_coop/bootstrap.gd`"`n`n[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$privateUserName`"`n"
    [IO.File]::WriteAllText((Join-Path $privateGameDir 'override.cfg'),$testOverride,[Text.UTF8Encoding]::new($false))
    $nativeRole = if ($nativeIndex -eq 0) { 'host' } else { 'guest' }
    $nativeLogPath = Join-Path $nativeWorkingLogDir ($nativeNames[$nativeIndex] + '.log')
    $nativeLogPaths += $nativeLogPath
    $nativeX = 20 + 660 * ($nativeIndex % 2)
    $nativeY = 20 + 420 * [math]::Floor($nativeIndex / 2)
    $nativeResolution = if ($Presence) { '1024x640' } else { '640x360' }
    $launchArguments = @(
        '--windowed','--resolution',$nativeResolution,'--position',($nativeX.ToString()+','+$nativeY.ToString()),
        '--max-fps','30','--render-thread','safe','--quit-after','90000','--log-file',('"'+$nativeLogPath+'"'),'--',
        '--ftn-coop-native-network-test','--ftn-coop-autoquit',
        ('--ftn-role='+$nativeRole),('--ftn-index='+$nativeIndex),('--ftn-count='+$Players),
        ('--ftn-port='+$nativePort),('--ftn-run='+$nativeRunId),('--ftn-build='+$nativeGameBuild)
    )
    if ($Presence) { $launchArguments += '--ftn-coop-presence-check' }
    if ($Persistence) { $launchArguments += '--ftn-coop-save-check' }
    if ($PerformanceSeconds -gt 0) { $launchArguments += ('--ftn-performance-seconds='+$PerformanceSeconds) }
    if ($peerHeadless) { $launchArguments = @('--headless','--audio-driver','Dummy') + $launchArguments }
    $nativeProcesses += Start-Process -FilePath (Join-Path $privateGameDir 'FindTheNeedle.exe') -ArgumentList $launchArguments -WorkingDirectory $privateGameDir -WindowStyle Hidden -PassThru
    if ($nativeIndex -lt ($Players-1)) {
        # Let the host finish before clients start their connection timeout.
        # Sequential loading also keeps cold native renderers from competing.
        $loadDeadline = (Get-Date).AddSeconds(120)
        while ((Get-Date) -lt $loadDeadline) {
            $loadedReport = Read-NativeReport $nativeNames[$nativeIndex]
            if ($null -ne $loadedReport -and ($loadedReport.stage -in @('dig_done','collab_ready') -or ($nativeIndex -eq 0 -and $loadedReport.revision -ge 0) -or $loadedReport.status -eq 'FAIL')) { break }
            Start-Sleep -Milliseconds 200
        }
    }
}
} finally { [Environment]::SetEnvironmentVariable('FTN_COOP_TEST_OUTPUT',$previousTestOutput,'Process') }
@{ run_id=$nativeRunId; game_build=$nativeGameBuild; source_manifest=$nativeManifestPath; players=$Players; process_ids=@($nativeProcesses | ForEach-Object { $_.Id }); game_copies=$nativeCopyRunRoot; private_profiles=$privateUserRoots; log_dir=$nativeLogDir; reports=$nativeReportDir; mod_source=$ModSource; mod_hashes=$nativeSourceHashes; headless=($nativeGraphicalPeers.Count -eq 0); headless_peers=$nativeHeadlessPeers; graphical_peers=$nativeGraphicalPeers; performance_seconds=$PerformanceSeconds; save_sha256=$(if ($SaveFile) { (Get-FileHash -LiteralPath $SaveFile -Algorithm SHA256).Hash } else { '' }); started=(Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $nativeLogDir 'request.json')
Write-Output "Started $Players native demo processes. Comparing per-revision shared-world hashes."
$nativeDeadline = (Get-Date).AddSeconds($(if ($PerformanceSeconds -gt 0) { $PerformanceSeconds+180 } elseif ($Presence) { if ($Players -eq 4) { 300 } else { 180 } } elseif ($Players -eq 4) { 200 } else { 100 }))
$nativeReports = @{}
$nativeAgreement = @{ ok=$false; mismatch=$false; counts=@{} }
$nativeFailure = ''
while ((Get-Date) -lt $nativeDeadline) {
    $nativeReports = @{}
    foreach ($reportName in $nativeNames) { $nativeReports[$reportName] = Read-NativeReport $reportName }
    $failedReports = @($nativeReports.Values | Where-Object { $null -ne $_ -and $_.status -eq 'FAIL' })
    if ($failedReports.Count -gt 0) { $nativeFailure = 'Native check failed: ' + (($failedReports | ForEach-Object { $_.code }) -join ', '); break }
    $missingOrPending = @($nativeReports.Values | Where-Object { $null -eq $_ -or -not $_.scenario_complete })
    if ($missingOrPending.Count -eq 0) {
        $nativeAgreement = Test-NativeAgreement $nativeReports
        if ($nativeAgreement.mismatch) { $nativeFailure = 'State mismatch for ' + $nativeAgreement.peer + ' at revision ' + $nativeAgreement.revision; break }
        if ($nativeAgreement.ok) { break }
    }
    $scriptErrors = @(Select-String -LiteralPath $nativeLogPaths -Pattern 'SCRIPT ERROR:|^ERROR:' -ErrorAction SilentlyContinue)
    if ($scriptErrors.Count -gt 0) { $nativeFailure = 'Native log contains a script or engine error.'; break }
    $anyExited = @($nativeProcesses | Where-Object { $_.HasExited })
    if ($anyExited.Count -gt 0) { $nativeFailure = 'A native process exited before completion.'; break }
    Start-Sleep -Milliseconds 200
}
if (-not $nativeAgreement.ok -and $nativeFailure -eq '') { $nativeFailure = 'Native network test timed out.' }
if ($nativeFailure -eq '' -and $ReviewSeconds -gt 0) {
    Write-Output 'Native checks passed; keeping the owned windows open briefly for visual review.'
    Start-Sleep -Seconds $ReviewSeconds
}
[IO.File]::WriteAllText((Join-Path $nativeReportDir 'stop.request'),'stop')
$closeDeadline = (Get-Date).AddSeconds($(if ($Persistence) { 50 } else { 20 }))
while ((Get-Date) -lt $closeDeadline -and @($nativeProcesses | Where-Object { -not $_.HasExited }).Count -gt 0) { Start-Sleep -Milliseconds 200 }
foreach ($nativeProcess in $nativeProcesses | Where-Object { -not $_.HasExited }) {
    $ownedProcess = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $nativeProcess.Id)
    if ($null -ne $ownedProcess -and $ownedProcess.ExecutablePath.StartsWith($nativeCopyRunRoot+'\',[StringComparison]::OrdinalIgnoreCase) -and $ownedProcess.CommandLine.Contains('--ftn-run='+$nativeRunId) -and $ownedProcess.CommandLine.Contains('--ftn-coop-native-network-test')) {
        Stop-Process -Id $nativeProcess.Id -Force
        $null = $nativeProcess.WaitForExit(5000)
        if ($nativeFailure -eq '') { $nativeFailure = 'Owned native test did not close after stop request.' }
    }
}
foreach ($reportName in $nativeNames) {
    $reportPath = Join-Path $nativeReportDir ($reportName+'.json')
    if (Test-Path -LiteralPath $reportPath) { Copy-Item -LiteralPath $reportPath -Destination (Join-Path $nativeLogDir ($reportName+'.json')) }
    $finalReport = Read-NativeReport $reportName
    if ($nativeFailure -eq '' -and ($null -eq $finalReport -or $finalReport.status -ne 'PASS')) {
        $nativeFailure = 'Final native check did not pass: ' + $reportName + ' ' + $finalReport.code
    }
}
$scriptErrors = @(Select-String -LiteralPath $nativeLogPaths -Pattern 'SCRIPT ERROR:|^ERROR:' -ErrorAction SilentlyContinue)
if ($scriptErrors.Count -gt 0 -and $nativeFailure -eq '') { $nativeFailure = 'Native log contains a script or engine error.' }
if ($Presence -and $nativeFailure -eq '') {
    $loadWitnesses = @($nativeNames | Where-Object { $_ -ne 'host' } | ForEach-Object { Read-NativeReport $_ } | Where-Object {
        $_.checks.tool_load_received -and $_.checks.tool_load_visible -and $_.checks.tool_load_emptied -and $_.checks.tool_straw_local -and $_.checks.tool_straw_released
    })
    if ($loadWitnesses.Count -eq 0) { $nativeFailure = 'No guest confirmed tool load, local carried-straw motion and release rendering.' }
    $beltWitnesses = @($nativeNames | Where-Object { $_ -ne 'host' } | ForEach-Object { Read-NativeReport $_ } | Where-Object {
        $_.checks.belt_view_rendered -and -not $_.checks.belt_view_misses
    })
    if ($beltWitnesses.Count -ne ($Players-1)) { $nativeFailure = 'Not every guest retained the native belt load at stable revisions without extra cargo or props.' }
}
$summary = @{ ok=($nativeFailure -eq ''); players=$Players; code=$nativeFailure; matching_revisions=$nativeAgreement.counts }
$summary | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $nativeLogDir 'summary.json')
if ($nativeWorkingLogDir -ne $nativeLogDir) {
    $archivedReports = Join-Path $nativeLogDir 'reports'
    New-Item -Path $archivedReports -ItemType Directory -Force | Out-Null
    Get-ChildItem -LiteralPath $nativeReportDir -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $archivedReports }
    Get-ChildItem -LiteralPath $nativeWorkingLogDir -Filter '*.log' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $nativeLogDir }
}
$summary | ConvertTo-Json -Compress | Write-Output
if ($nativeFailure -ne '') {
    foreach ($nativeLogPath in $nativeLogPaths) {
        Get-Content -LiteralPath $nativeLogPath -Tail 12 -ErrorAction SilentlyContinue
    }
    exit 1
}
Write-Output "PASS native $Players-player shared-world check. Internet/Steam-account validation remains separate."
exit 0
