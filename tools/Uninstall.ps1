param([Parameter(Mandatory)][string]$GameDir, [ValidateSet('auto','de','en')][string]$Language = 'auto')
$ErrorActionPreference = 'Stop'
if ($Language -eq 'auto') { $Language = if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'de') { 'de' } else { 'en' } }
$gameRoot = (Resolve-Path -LiteralPath $GameDir).Path.TrimEnd('\')
$gameExe = Join-Path $gameRoot 'FindTheNeedle.exe'
if (-not (Test-Path -LiteralPath $gameExe) -or -not (Test-Path -LiteralPath (Join-Path $gameRoot 'FindTheNeedle.pck'))) { throw 'GAME_FOLDER_INVALID' }
foreach ($gameProcess in @(Get-Process -Name FindTheNeedle -ErrorAction SilentlyContinue)) {
    if (-not $gameProcess.Path -or $gameProcess.Path -eq $gameExe) { throw 'GAME_RUNNING: Close the game before removing the mod.' }
}
$modRoot = Join-Path $gameRoot 'mods\ftn_coop'
$manifestPath = Join-Path $modRoot 'install-state.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'MANIFEST_MISSING: Nothing removed.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.format -ne 'FTN-Coop-1') { throw 'MANIFEST_INVALID' }
foreach ($entry in $manifest.files) {
    if ($entry.path -notmatch '^[a-z_]+\.gd$') { throw 'MANIFEST_PATH_INVALID: Nothing removed.' }
}
$configPath = Join-Path $gameRoot 'override.cfg'
if (Test-Path -LiteralPath $configPath) {
    $currentHash = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
    if ($currentHash -eq $manifest.installed_cfg_sha256) {
        if ($manifest.original_cfg_existed) {
            [System.IO.File]::WriteAllBytes($configPath, [Convert]::FromBase64String($manifest.original_cfg_base64))
        } else { Remove-Item -LiteralPath $configPath -Force }
    } else {
        # Preserve unrelated edits made after installation.
        $bytes = [System.IO.File]::ReadAllBytes($configPath)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
        $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes).TrimStart([char]0xFEFF)
        $text = [regex]::Replace($text, '(?m)^[ \t]*FtnCoop[ \t]*=[ \t]*"\*mods/ftn_coop/bootstrap\.gd"[ \t]*(?:\r?\n|$)', '')
        [System.IO.File]::WriteAllText($configPath, $text, [System.Text.UTF8Encoding]::new($hasBom))
    }
}
$retained = $false
foreach ($entry in $manifest.files) {
    $file = Join-Path $modRoot $entry.path
    if (-not (Test-Path -LiteralPath $file)) { continue }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -eq $entry.sha256) {
        Remove-Item -LiteralPath $file -Force
    } else {
        $retained = $true
        $message = if ($Language -eq 'de') { 'Lokal geaenderte eigene Datei beibehalten: ' } else { 'Preserved locally changed own file: ' }
        Write-Output ('LOCAL_MOD_PRESERVED: '+$message+$entry.path)
    }
}
if (-not $retained) {
    Remove-Item -LiteralPath $manifestPath -Force
    if (@(Get-ChildItem -LiteralPath $modRoot -Force).Count -eq 0) { Remove-Item -LiteralPath $modRoot }
    $modsRoot = Join-Path $gameRoot 'mods'
    if (-not $manifest.original_mods_existed -and (Test-Path -LiteralPath $modsRoot) -and @(Get-ChildItem -LiteralPath $modsRoot -Force).Count -eq 0) {
        Remove-Item -LiteralPath $modsRoot
    }
}
if ($Language -eq 'de') { Write-Output 'Eigener FTN-Koop-Start entfernt; andere Mods und Einstellungen beibehalten.' }
else { Write-Output 'Own FTN-Coop autoload removed; unrelated mods and settings preserved.' }
