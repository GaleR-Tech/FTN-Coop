$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
# Deliberate file list: never archive the workspace or original game recursively.
$runtimeNames = @(
    'avatar','bootstrap','coop_runtime','coop_ui','game_adapter','game_bindings',
    'guest_movement','input_bridge','integration_probe','local_transport','loose_sync',
    'native_actor','native_network_check','network_controller','presence','protocol','locale','mod_version',
    'runtime_probe','save_session','session','snapshot_transfer','steam_transport',
    'value_codec','world_sync'
)
$files = @('Install.cmd','Remove.cmd','Installieren.cmd','Entfernen.cmd','README.md','README.en.md','README.de.md','THIRD_PARTY_NOTICES.txt','LICENSE','LICENSE.en.txt',
    'tools/Install.ps1','tools/Uninstall.ps1','tools/Setup.ps1','docs/playtest-checklist.md','docs/playtest-checklist.en.md')
$files += @($runtimeNames | ForEach-Object { 'mods/ftn_coop/'+$_+'.gd' })
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $file) -PathType Leaf)) { throw ('PACKAGE_FILE_MISSING: '+$file) }
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$outputRoot = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$archivePath = Join-Path $outputRoot 'FTN-Coop-0.1.3.zip'
$temporaryPath = $archivePath+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
try {
    $archive = [IO.Compression.ZipFile]::Open($temporaryPath,[IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $files) {
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $projectRoot $file),$file,[IO.Compression.CompressionLevel]::Optimal)
        }
    }
    finally { $archive.Dispose() }
    Move-Item -LiteralPath $temporaryPath -Destination $archivePath -Force
}
finally { if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath } }
$digest = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($archivePath+'.sha256',$digest+'  FTN-Coop-0.1.3.zip'+[Environment]::NewLine)
Write-Output ('Paket erstellt: '+$archivePath+' ('+$files.Count+' Dateien)')
