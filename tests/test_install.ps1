$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$install = Join-Path $projectRoot 'tools\Install.ps1'
$uninstall = Join-Path $projectRoot 'tools\Uninstall.ps1'
if (-not (Test-Path -LiteralPath $install) -or -not (Test-Path -LiteralPath $uninstall)) {
    throw 'Reversible installation is not implemented yet.'
}
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ftn-coop-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
function New-TestGame([string]$Name) {
    $folder = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $folder | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $folder 'FindTheNeedle.exe'), [byte[]](1,2,3))
    [System.IO.File]::WriteAllBytes((Join-Path $folder 'FindTheNeedle.pck'), [byte[]](4,5,6))
    return $folder
}
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
$game = New-TestGame 'existing-config'
$config = Join-Path $game 'override.cfg'
$original = "[display]`r`nname=`"keep me`"`r`n[autoload]`r`nOtherMod=`"*mods/other.gd`"`r`n"
[System.IO.File]::WriteAllText($config, $original, [System.Text.UTF8Encoding]::new($true))
$originalBytes = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($config))
& $install -GameDir $game | Out-Null
Require ((Get-Content -LiteralPath $config -Raw).Contains('OtherMod=')) 'Other autoload was lost.'
& $install -GameDir $game | Out-Null
Require (([regex]::Matches((Get-Content -LiteralPath $config -Raw), '(?m)^FtnCoop=')).Count -eq 1) 'Duplicate autoload entry.'
& $uninstall -GameDir $game | Out-Null
Require ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($config)) -eq $originalBytes) 'Original config bytes were not restored.'
Require ((Get-FileHash -LiteralPath (Join-Path $game 'FindTheNeedle.exe')).Hash -eq (Get-FileHash -LiteralPath (Join-Path (New-TestGame 'comparison') 'FindTheNeedle.exe')).Hash) 'Original executable changed.'

$game = New-TestGame 'later-config-change'
$config = Join-Path $game 'override.cfg'
& $install -GameDir $game | Out-Null
Add-Content -LiteralPath $config -Value "[unrelated]`nsetting=42" -Encoding utf8
& $install -GameDir $game | Out-Null
& $uninstall -GameDir $game | Out-Null
Require ((Get-Content -LiteralPath $config -Raw).Contains('setting=42')) 'Later user settings were lost after updating the mod.'
Require (-not (Get-Content -LiteralPath $config -Raw).Contains('FtnCoop=')) 'Own autoload entry remained.'

$game = New-TestGame 'unrelated-mod'
$otherFolder = Join-Path $game 'mods\other'
New-Item -ItemType Directory -Path $otherFolder -Force | Out-Null
Set-Content -LiteralPath (Join-Path $otherFolder 'keep.txt') -Value 'keep'
& $install -GameDir $game | Out-Null
& $uninstall -GameDir $game | Out-Null
Require (Test-Path -LiteralPath (Join-Path $otherFolder 'keep.txt')) 'An unrelated mod was removed.'
Require (-not (Test-Path -LiteralPath (Join-Path $game 'override.cfg'))) 'Originally missing config was not removed.'

$game = New-TestGame 'edited-own-file'
& $install -GameDir $game | Out-Null
$edited = Join-Path $game 'mods\ftn_coop\bootstrap.gd'
Add-Content -LiteralPath $edited -Value '# edited locally'
& $uninstall -GameDir $game | Out-Null
Require (Test-Path -LiteralPath $edited) 'A locally edited mod file was deleted.'
$game = New-TestGame 'windows-powershell'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $install -GameDir $game
Require ($LASTEXITCODE -eq 0) 'Bundled Windows PowerShell could not install the package.'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $uninstall -GameDir $game
Require ($LASTEXITCODE -eq 0) 'Bundled Windows PowerShell could not remove the package.'
$game = New-TestGame 'old-manifest-new-file-collision'
& $install -GameDir $game | Out-Null
$manifestPath = Join-Path $game 'mods\ftn_coop\install-state.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.files = @($manifest.files | Where-Object { $_.path -ne 'locale.gd' })
[IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$collisionPath = Join-Path $game 'mods\ftn_coop\locale.gd'
[IO.File]::WriteAllText($collisionPath,'# local file predating the update',[Text.UTF8Encoding]::new($false))
$manifestHash = (Get-FileHash -LiteralPath $manifestPath).Hash
$configHash = (Get-FileHash -LiteralPath (Join-Path $game 'override.cfg')).Hash
$refused = $false
try { & $install -GameDir $game | Out-Null }
catch { $refused = $_.Exception.Message.Contains('LOCAL_MOD_CHANGED') }
Require $refused 'An update must refuse an incoming file that collides with an unowned local file.'
Require ([IO.File]::ReadAllText($collisionPath) -eq '# local file predating the update') 'Unowned local file was overwritten.'
Require ((Get-FileHash -LiteralPath $manifestPath).Hash -eq $manifestHash) 'Refused update changed the installation manifest.'
Require ((Get-FileHash -LiteralPath (Join-Path $game 'override.cfg')).Hash -eq $configHash) 'Refused update changed config.'
Write-Output 'PASS installation_preserves_config_and_other_mods (6 scenarios)'
exit 0
