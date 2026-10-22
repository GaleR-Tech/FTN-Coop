param([string]$SetupPath = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $projectRoot 'tools\BuildInstaller.ps1'
if (-not (Test-Path -LiteralPath $builder)) { throw 'EXE installer builder is missing.' }
if ($SetupPath) { $setup = $SetupPath }
else {
    & $builder
    $setup = Join-Path $projectRoot 'dist\FTN-Coop-0.6.3-Setup.exe'
}
if (-not (Test-Path -LiteralPath $setup)) { throw 'Single-file EXE installer was not built.' }
function Require([bool]$condition,[string]$message) { if (-not $condition) { throw $message } }
function Run-Setup([string]$action,[string]$game) {
    $process = Start-Process -FilePath $setup -ArgumentList @($action,('"'+$game+'"')) -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(30000)) { Stop-Process -Id $process.Id; throw 'Owned installer test timed out.' }
    return $process.ExitCode
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ftn-coop-exe-'+[guid]::NewGuid().ToString('N'))
$game = Join-Path $testRoot 'Demo mit Leerzeichen & Umlaut ä'
$null = New-Item -ItemType Directory -Path $game -Force
foreach ($name in @('FindTheNeedle.exe','FindTheNeedle.pck')) { [IO.File]::WriteAllBytes((Join-Path $game $name),[byte[]](1,2,3)) }
$config = Join-Path $game 'override.cfg'
$original = "[autoload]`r`nOtherMod=`"*mods/other.gd`"`r`n"
[IO.File]::WriteAllText($config,$original,[Text.UTF8Encoding]::new($true))
$originalBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($config))
$binaries = @(Get-FileHash -LiteralPath (Join-Path $game 'FindTheNeedle.exe'),(Join-Path $game 'FindTheNeedle.pck'))
Require ((Run-Setup '--install' $game) -eq 0) 'EXE installation failed.'
foreach ($source in Get-ChildItem (Join-Path $projectRoot 'mods\ftn_coop') -Filter '*.gd' -File) {
    $installed = Join-Path $game ('mods\ftn_coop\'+$source.Name)
    Require ((Get-FileHash -LiteralPath $installed).Hash -eq (Get-FileHash -LiteralPath $source.FullName).Hash) ('EXE payload differs: '+$source.Name)
}
Require ((Run-Setup '--install' $game) -eq 0) 'EXE repeat installation failed.'
Require ((Run-Setup '--remove' $game) -eq 0) 'EXE removal failed.'
Require ([Convert]::ToBase64String([IO.File]::ReadAllBytes($config)) -eq $originalBytes) 'EXE removal did not restore original config bytes.'
foreach ($binary in $binaries) { Require ((Get-FileHash -LiteralPath $binary.Path).Hash -eq $binary.Hash) 'EXE installer changed an original game binary.' }

Require ((Run-Setup '--install' $game) -eq 0) 'EXE reinstall failed.'
Add-Content -LiteralPath $config -Value "[later]`nkeep=42"
Require ((Run-Setup '--install' $game) -eq 0) 'EXE update failed.'
Require ((Run-Setup '--remove' $game) -eq 0) 'EXE removal after update failed.'
Require ((Get-Content $config -Raw).Contains('keep=42')) 'EXE update/removal lost later settings.'
Require ((Run-Setup '--install' $testRoot) -ne 0) 'EXE accepted an invalid game directory.'

Require ((Run-Setup '--install' $game) -eq 0) 'EXE installation for local-edit test failed.'
$edited = Join-Path $game 'mods\ftn_coop\bootstrap.gd'
Add-Content -LiteralPath $edited -Value '# user changed this'
Require ((Run-Setup '--install' $game) -ne 0) 'EXE overwrote a locally edited mod file.'
Require ((Run-Setup '--remove' $game) -eq 0) 'EXE removal with local edits failed.'
Require (Test-Path -LiteralPath $edited) 'EXE removal deleted a locally edited mod file.'
Add-Type -AssemblyName System.Drawing
foreach ($language in @('', '-de', '-en')) {
    $preview = Join-Path $projectRoot ('verification\installer-preview'+$language+'.png')
    Require ((Run-Setup ('--render-preview'+$language) $preview) -eq 0) ('Installer preview failed to render: '+$language)
    Require (Test-Path -LiteralPath $preview) ('Installer window preview is missing: '+$language)
    $picture = [Drawing.Bitmap]::new($preview)
    try {
        $colors = [Collections.Generic.HashSet[int]]::new()
        for ($x=35; $x -lt $picture.Width-35; $x+=8) {
            for ($y=45; $y -lt $picture.Height-35; $y+=8) { $null=$colors.Add($picture.GetPixel($x,$y).ToArgb()) }
        }
        Require ($colors.Count -gt 8) ('Installer preview is blank instead of showing its actual controls: '+$language)
    }
    finally { $picture.Dispose() }
}
Require ((Get-FileHash -LiteralPath (Join-Path $projectRoot 'verification\installer-preview-de.png')).Hash -ne (Get-FileHash -LiteralPath (Join-Path $projectRoot 'verification\installer-preview-en.png')).Hash) 'German and English preview switches rendered the same language.'
Write-Output 'PASS standalone_exe_install_update_remove_and_preview'
