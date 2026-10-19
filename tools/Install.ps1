param([Parameter(Mandatory)][string]$GameDir, [ValidateSet('auto','de','en')][string]$Language = 'auto')
$ErrorActionPreference = 'Stop'
if ($Language -eq 'auto') { $Language = if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'de') { 'de' } else { 'en' } }
$gameRoot = (Resolve-Path -LiteralPath $GameDir).Path.TrimEnd('\')
$gameExe = Join-Path $gameRoot 'FindTheNeedle.exe'
if (-not (Test-Path -LiteralPath $gameExe) -or -not (Test-Path -LiteralPath (Join-Path $gameRoot 'FindTheNeedle.pck'))) {
    throw 'GAME_FOLDER_INVALID: Expected FindTheNeedle.exe and FindTheNeedle.pck.'
}
foreach ($gameProcess in @(Get-Process -Name FindTheNeedle -ErrorAction SilentlyContinue)) {
    if (-not $gameProcess.Path -or $gameProcess.Path -eq $gameExe) { throw 'GAME_RUNNING: Close the game before installing.' }
}
$sourceRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'mods\ftn_coop'
$modRoot = Join-Path $gameRoot 'mods\ftn_coop'
$manifestPath = Join-Path $modRoot 'install-state.json'
$configPath = Join-Path $gameRoot 'override.cfg'
$configExisted = Test-Path -LiteralPath $configPath
[byte[]]$originalBytes = @()
if ($configExisted) { $originalBytes = [System.IO.File]::ReadAllBytes($configPath) }
if ($originalBytes.Length -gt 1048576) { throw 'CONFIG_TOO_LARGE: Refusing to change this file.' }
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$configText = $utf8.GetString($originalBytes).TrimStart([char]0xFEFF)
$ownEntry = 'FtnCoop="*mods/ftn_coop/bootstrap.gd"'
$existingEntry = [regex]::Match($configText, '(?m)^[ \t]*FtnCoop[ \t]*=.*$')
if ($existingEntry.Success -and $existingEntry.Value.Trim() -ne $ownEntry) { throw 'AUTOLOAD_CONFLICT: FtnCoop already points elsewhere.' }
$manifest = $null
$preserveConfigEdits = $false
if (Test-Path -LiteralPath $modRoot) {
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'MOD_FOLDER_CONFLICT: Existing folder has no installation manifest.' }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.format -ne 'FTN-Coop-1') { throw 'MANIFEST_INVALID' }
    $preserveConfigEdits = -not $configExisted -or (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash -ne $manifest.installed_cfg_sha256
    foreach ($entry in $manifest.files) {
        if ($entry.path -notmatch '^[a-z_]+\.gd$') { throw 'MANIFEST_PATH_INVALID' }
        $existingFile = Join-Path $modRoot $entry.path
        if ((Test-Path -LiteralPath $existingFile) -and (Get-FileHash -LiteralPath $existingFile -Algorithm SHA256).Hash -ne $entry.sha256) {
            throw 'LOCAL_MOD_CHANGED: Preserve local edits before updating.'
        }
    }
}
$newline = if ($configText.Contains("`r`n")) { "`r`n" } else { "`n" }
if (-not $existingEntry.Success) {
    $section = [regex]::Match($configText, '(?m)^\[autoload\][ \t]*(?:\r?\n|$)')
    if ($section.Success) {
        $insertion = $section.Index + $section.Length
        $prefix = if ($section.Value.EndsWith("`n")) { '' } else { $newline }
        $configText = $configText.Insert($insertion, $prefix + $ownEntry + $newline)
    } else {
        if ($configText.Length -gt 0 -and -not $configText.EndsWith("`n")) { $configText += $newline }
        $configText += '[autoload]' + $newline + $ownEntry + $newline
    }
}
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File -Filter '*.gd')
if ($sourceFiles.Count -eq 0) { throw 'PACKAGE_EMPTY' }
# New version files may collide with local files absent from the old manifest.
# Complete this preflight before writing config, files or rollback information.
$ownedNames = @{}
if ($null -ne $manifest) { foreach ($entry in $manifest.files) { $ownedNames[$entry.path] = $true } }
foreach ($sourceFile in $sourceFiles) {
    if ((Test-Path -LiteralPath (Join-Path $modRoot $sourceFile.Name)) -and -not $ownedNames.ContainsKey($sourceFile.Name)) {
        throw 'LOCAL_MOD_CHANGED: An incoming file would overwrite an unmanaged local file.'
    }
}
if ($null -eq $manifest) {
    $manifest = [pscustomobject]@{
        format = 'FTN-Coop-1'
        original_cfg_existed = $configExisted
        original_cfg_base64 = [Convert]::ToBase64String($originalBytes)
        original_mods_existed = (Test-Path -LiteralPath (Join-Path $gameRoot 'mods'))
        installed_cfg_sha256 = ''
        files = @()
    }
}
$installedBytes = [System.Text.Encoding]::UTF8.GetBytes($configText)
$configHasher = [System.Security.Cryptography.SHA256]::Create()
try {
    # Keep the old baseline when users changed config after installation.
    # Removal must then edit only our entry, even after a mod update.
    if (-not $preserveConfigEdits) { $manifest.installed_cfg_sha256 = [BitConverter]::ToString($configHasher.ComputeHash($installedBytes)).Replace('-','') }
}
finally { $configHasher.Dispose() }
$manifest.files = @($sourceFiles | ForEach-Object { [pscustomobject]@{ path = $_.Name; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } })
New-Item -ItemType Directory -Path $modRoot -Force | Out-Null
# Save rollback information before changing configuration or copying files.
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
foreach ($sourceFile in $sourceFiles) { Copy-Item -LiteralPath $sourceFile.FullName -Destination (Join-Path $modRoot $sourceFile.Name) -Force }
[System.IO.File]::WriteAllBytes($configPath, $installedBytes)
if ($Language -eq 'de') { Write-Output 'FTN-Koop installiert. Spiel normal ueber Steam starten und F2 druecken.' }
else { Write-Output 'FTN-Coop installed. Launch the game through Steam and press F2.' }
