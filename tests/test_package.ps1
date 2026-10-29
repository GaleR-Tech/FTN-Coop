$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $projectRoot 'tools\Package.ps1'
if (-not (Test-Path -LiteralPath $builder)) { throw 'Package builder is missing.' }
& $builder
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archivePath = Join-Path $projectRoot 'dist\0.7\0.7.2\FTN-Coop-0.7.2.zip'
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $names = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
    $expected = @('Install.cmd','Remove.cmd','Installieren.cmd','Entfernen.cmd','README.md','README.en.md','README.de.md','THIRD_PARTY_NOTICES.txt','LICENSE','LICENSE.en.txt','tools/Install.ps1','tools/Uninstall.ps1','tools/Setup.ps1','docs/playtest-checklist.md','docs/playtest-checklist.en.md')
    $expected += @(Get-ChildItem (Join-Path $projectRoot 'mods\ftn_coop') -Filter '*.gd' -File | ForEach-Object { 'mods/ftn_coop/'+$_.Name })
    if (@(Compare-Object ($expected | Sort-Object) ($names | Sort-Object)).Count -ne 0) { throw 'Archive contains missing or unapproved files.' }
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -match '\.(exe|dll|pck|log|dat|uid)$|(^|/)(\.git|\.tools|verification|downloads|backups)(/|$)') { throw ('Private or original file in archive: '+$entry.FullName) }
        $sourcePath = Join-Path $projectRoot $entry.FullName
        $stream = $entry.Open()
        $hash = [Security.Cryptography.SHA256]::Create()
        try { $actual = [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','') }
        finally { $stream.Dispose(); $hash.Dispose() }
        if ($actual -ne (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash) { throw ('Archive differs from source: '+$entry.FullName) }
    }
    $readme = Get-Content (Join-Path $projectRoot 'README.md') -Raw
    if ($readme -notmatch '0\.7\.2' -or $readme -notmatch '26260645' -or $readme -notmatch 'unbestätigt') { throw 'Version, build and Internet-test limitation must be documented.' }
    if ((Get-Content (Join-Path $projectRoot 'mods\ftn_coop/bootstrap.gd') -Raw) -notmatch 'const VERSION := "0\.7\.2"') { throw 'Documented version differs from runtime.' }
}
finally { $archive.Dispose() }
$extractRoot = Join-Path ([IO.Path]::GetTempPath()) ('ftn-coop-package-'+[guid]::NewGuid().ToString('N'))
[IO.Compression.ZipFile]::ExtractToDirectory($archivePath,$extractRoot)
$testGame = Join-Path $extractRoot 'synthetic-game'
$null = New-Item -ItemType Directory -Path $testGame
foreach ($name in @('FindTheNeedle.exe','FindTheNeedle.pck')) { [IO.File]::WriteAllBytes((Join-Path $testGame $name),[byte[]](1,2,3)) }
$setup = Join-Path $extractRoot 'tools\Setup.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup -Action Install -GameDir $testGame -NonInteractive
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $testGame 'mods\ftn_coop\save_session.gd'))) { throw 'Extracted package could not install with Windows PowerShell.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup -Action Remove -GameDir $testGame -NonInteractive
if ($LASTEXITCODE -ne 0 -or (Test-Path (Join-Path $testGame 'override.cfg'))) { throw 'Extracted package did not remove cleanly.' }
Write-Output ('PASS package_allowlist_and_source_hashes ('+$names.Count+' files)')
