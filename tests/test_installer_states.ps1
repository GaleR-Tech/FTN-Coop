param([string]$SetupPath = '', [switch]$Worker)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $SetupPath) {
    & (Join-Path $projectRoot 'tools/BuildInstaller.ps1')
    $SetupPath = Join-Path $projectRoot 'dist/FTN-Coop-0.1.4-Setup.exe'
}
if (-not $Worker) {
    $logBase = Join-Path ([IO.Path]::GetTempPath()) ('ftn-installer-states-'+[guid]::NewGuid().ToString('N'))
    $outputLog = $logBase+'.out'
    $errorLog = $logBase+'.err'
    try {
        $process = Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',('"'+$PSCommandPath+'"'),'-SetupPath',('"'+$SetupPath+'"'),'-Worker') -WindowStyle Hidden -RedirectStandardOutput $outputLog -RedirectStandardError $errorLog -PassThru
        if (-not $process.WaitForExit(60000)) { Stop-Process -Id $process.Id; throw 'Installer state checks timed out.' }
        Write-Output ([IO.File]::ReadAllText($outputLog))
        if ($process.ExitCode -ne 0) { throw ([IO.File]::ReadAllText($errorLog)) }
    }
    finally { Remove-Item -LiteralPath $outputLog,$errorLog -Force -ErrorAction SilentlyContinue }
    return
}
Add-Type -AssemblyName System.Windows.Forms
$assembly = [Reflection.Assembly]::LoadFrom($SetupPath)
$flags = [Reflection.BindingFlags]'Static,NonPublic'
$instance = [Reflection.BindingFlags]'Instance,NonPublic,Public'
$program = $assembly.GetType('Program',$true)
$inspect = $program.GetMethod('InspectInstallation',$flags)
if ($null -eq $inspect) { throw 'Installer cannot inspect the installed mod version yet.' }
function Require([bool]$condition,[string]$message) { if (-not $condition) { throw $message } }
function Inspect([string]$path) { return $inspect.Invoke($null,[object[]]@($path)) }
function Field($value,[string]$name) { return $value.GetType().GetField($name,$instance).GetValue($value) }
function Control($form,[string]$name) {
    $found = @($form.Controls.Find($name,$true))
    Require ($found.Count -eq 1) ('Missing accessible installer control: '+$name)
    return $found[0]
}
function New-SyntheticGame([string]$name) {
    $path = Join-Path $testRoot $name
    $null = New-Item -ItemType Directory -Path $path -Force
    foreach ($file in @('FindTheNeedle.exe','FindTheNeedle.pck')) { [IO.File]::WriteAllBytes((Join-Path $path $file),[byte[]](1,2,3)) }
    return $path
}
function Invoke-Operation([string]$action,[string]$gamePath) {
    $method = $program.GetMethod('Install',$flags,$null,[type[]]@([string],[string]),$null)
    $result = $method.Invoke($null,[object[]]@($action,$gamePath))
    Require ((Field $result 'Code') -eq 0) ('Synthetic setup operation failed: '+$action)
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ftn-installer-inspection-'+[guid]::NewGuid().ToString('N'))
$game = Join-Path $testRoot 'Synthetic demo & space'
$null = New-Item -ItemType Directory -Path $game -Force
foreach ($name in @('FindTheNeedle.exe','FindTheNeedle.pck')) { [IO.File]::WriteAllBytes((Join-Path $game $name),[byte[]](1,2,3)) }
$result = Inspect $testRoot
Require (-not (Field $result 'FolderValid')) 'A parent folder must not be mistaken for the demo.'
$result = Inspect $game
Require ((Field $result 'FolderValid') -and -not (Field $result 'Managed')) 'A clean demo must be shown as not installed.'
$formType = $assembly.GetType('SetupForm',$true)
[Threading.Thread]::CurrentThread.CurrentUICulture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
$form = [Activator]::CreateInstance($formType,$instance,$null,[object[]]@($true),$null)
try {
    $directory = Control $form 'GameDirectory'
    $directory.Text = $game
    Require ((Control $form 'InstallAction').Text -eq 'Install') 'A clean demo needs an Install action.'
    Require (-not (Control $form 'RemoveAction').Enabled) 'Remove must be unavailable without a managed installation.'
    Require ((Control $form 'TargetVersion').Text.Contains('0.1.4')) 'The package version must be visible.'

    $mod = Join-Path $game 'mods/ftn_coop'
    $null = New-Item -ItemType Directory -Path $mod -Force
    $manifestPath = Join-Path $mod 'install-state.json'
    $bootstrap = Join-Path $mod 'bootstrap.gd'
    [IO.File]::WriteAllText($manifestPath,'{"format":"FTN-Coop-1","files":[]}',[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($bootstrap,'const VERSION := "0.1.2"',[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $game 'override.cfg'),'[autoload]'+[Environment]::NewLine+'FtnCoop="*mods/ftn_coop/bootstrap.gd"',[Text.UTF8Encoding]::new($false))
    $result = Inspect $game
    Require ((Field $result 'Managed') -and (Field $result 'Version') -eq '0.1.2') 'Old manifests must recover the installed version from the own bootstrap without executing it.'
    $directory.Text = $testRoot
    $directory.Text = $game
    Require ((Control $form 'InstallAction').Text -eq 'Update') 'An older installation needs an Update action.'
    Require ((Control $form 'InstalledVersion').Text.Contains('0.1.2')) 'The installed version must be visible.'
    Require ((Control $form 'RemoveAction').Enabled) 'A managed installation can be removed.'
    $configPath = Join-Path $game 'override.cfg'
    foreach ($inactiveConfig in @(
        ('[other]'+[Environment]::NewLine+'FtnCoop="*mods/ftn_coop/bootstrap.gd"'),
        ('[autoload]'+[Environment]::NewLine+'; FtnCoop="*mods/ftn_coop/bootstrap.gd"')
    )) {
        [IO.File]::WriteAllText($configPath,$inactiveConfig,[Text.UTF8Encoding]::new($false))
        $directory.Text = $testRoot
        $directory.Text = $game
        Require ((Control $form 'InstalledVersion').Text -eq 'Not installed') 'An entry in another section or comment must not count as an active mod.'
    }

    [IO.File]::WriteAllText($manifestPath,'{"format":"FTN-Coop-1","mod_version":"0.1.4","files":[]}',[Text.UTF8Encoding]::new($false))
    Require ((Field (Inspect $game) 'Version') -eq '0.1.4') 'New installation metadata must identify the current installed version.'
    [IO.File]::WriteAllText($manifestPath,'{"format":"FTN-Coop-1","mod_version":"0.1.4\nPRIVATE_DATA","files":[]}',[Text.UTF8Encoding]::new($false))
    Require ((Field (Inspect $game) 'Version') -eq '') 'Invalid version metadata must not be displayed as a version.'
    foreach ($invalid in @('{broken json','{"format":"OTHER","files":[]}',('x'*2097153))) {
        [IO.File]::WriteAllText($manifestPath,$invalid,[Text.UTF8Encoding]::new($false))
        Require (Field (Inspect $game) 'Conflict') 'Invalid or oversized installation metadata must be recognized as a conflict.'
    }
    [IO.File]::Delete($manifestPath)
    Require (Field (Inspect $game) 'Conflict') 'An unmanaged existing mod folder must be recognized as a conflict.'

    $edgeIssues = @()
    $largeGame = New-SyntheticGame 'large-original-config'
    [IO.File]::WriteAllText((Join-Path $largeGame 'override.cfg'),('[local]'+[Environment]::NewLine+'value='+('x'*800000)),[Text.UTF8Encoding]::new($false))
    Invoke-Operation 'Install' $largeGame
    $largeInfo = Inspect $largeGame
    if (-not (Field $largeInfo 'Managed') -or (Field $largeInfo 'Conflict')) { $edgeIssues += 'A valid manifest with a large original config must remain manageable.' }

    $retainedGame = New-SyntheticGame 'removed-with-local-file'
    Invoke-Operation 'Install' $retainedGame
    $edited = Join-Path $retainedGame 'mods/ftn_coop/bootstrap.gd'
    Add-Content -LiteralPath $edited -Value '# retained local edit'
    Invoke-Operation 'Remove' $retainedGame
    $directory.Text = $retainedGame
    if ((Control $form 'InstalledVersion').Text -ne 'Not installed' -or (Control $form 'InstallAction').Text -ne 'Install') { $edgeIssues += 'Removed mods with retained local files must not appear as an active installed version.' }
    Require (Test-Path -LiteralPath $edited) 'Inspection must preserve retained local edits.'
    Require ($edgeIssues.Count -eq 0) ($edgeIssues -join ' ')
    Write-Output 'PASS installer_installed_versions_legacy_metadata_folder_switching_and_conflicts'
}
finally { $form.Dispose() }
