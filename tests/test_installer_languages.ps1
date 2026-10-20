param([string]$SetupPath = '', [switch]$Worker)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $SetupPath) {
    & (Join-Path $projectRoot 'tools\BuildInstaller.ps1')
    $SetupPath = Join-Path $projectRoot 'dist\FTN-Coop-0.4.1-Setup.exe'
}
if (-not $Worker) {
    # Isolate Windows Forms and culture changes, and bound unexpected modal dialogs.
    $logBase = Join-Path ([IO.Path]::GetTempPath()) ('ftn-installer-language-worker-'+[guid]::NewGuid().ToString('N'))
    $outputLog = $logBase+'.out'
    $errorLog = $logBase+'.err'
    try {
        $process = Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',('"'+$PSCommandPath+'"'),'-SetupPath',('"'+$SetupPath+'"'),'-Worker') -WindowStyle Hidden -RedirectStandardOutput $outputLog -RedirectStandardError $errorLog -PassThru
        if (-not $process.WaitForExit(60000)) {
            Stop-Process -Id $process.Id
            throw 'Installer language checks timed out (an unexpected dialog may have opened).'
        }
        if (Test-Path -LiteralPath $outputLog) { Write-Output ([IO.File]::ReadAllText($outputLog)) }
        if ($process.ExitCode -ne 0) { throw ('Installer language checks failed. '+[IO.File]::ReadAllText($errorLog)) }
    }
    finally { Remove-Item -LiteralPath $outputLog,$errorLog -Force -ErrorAction SilentlyContinue }
    return
}
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'The language test worker requires Windows PowerShell and .NET Framework.' }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$assembly = [Reflection.Assembly]::LoadFrom($SetupPath)
$formType = $assembly.GetType('SetupForm', $true)
$programType = $assembly.GetType('Program', $true)
$instanceFlags = [Reflection.BindingFlags]'Instance,NonPublic'
$staticFlags = [Reflection.BindingFlags]'Static,NonPublic'
$installMethod = $programType.GetMethod('Install', $staticFlags, $null, [type[]]@([string],[string]), $null)
function Require([bool]$condition,[string]$message) { if (-not $condition) { throw $message } }
function New-SetupForm([string]$culture) {
    [Threading.Thread]::CurrentThread.CurrentUICulture = [Globalization.CultureInfo]::GetCultureInfo($culture)
    return [Activator]::CreateInstance($formType, $instanceFlags, $null, [object[]]@($true), $null)
}
function Require-Caption($form,[string]$caption) {
    Require (@(Get-FormControls $form | Where-Object Text -eq $caption).Count -eq 1) ('Missing translated control: '+$caption)
}
function Get-FormControls($parent) {
    foreach ($child in $parent.Controls) { Write-Output $child; Get-FormControls $child }
}
function Invoke-Install([string]$action,[string]$game,[string]$culture) {
    [Threading.Thread]::CurrentThread.CurrentUICulture = [Globalization.CultureInfo]::GetCultureInfo($culture)
    $result = $installMethod.Invoke($null, [object[]]@($action,$game))
    return [pscustomobject]@{
        Code = $result.GetType().GetField('Code',$instanceFlags).GetValue($result)
        Message = $result.GetType().GetField('Message',$instanceFlags).GetValue($result)
    }
}
function Complete-FormOperation($form,$selector,$directory,[string]$action) {
    $operation = $formType.GetMethod('Run',$instanceFlags).Invoke($form,[object[]]@($action))
    Require (-not $selector.Enabled) ('Language changes must be disabled during '+$action+'.')
    Require (-not $directory.Enabled) ('The demo folder must be disabled during '+$action+'.')
    $progress = @($form.Controls.Find('StageProgress',$true))[0]
    Require ($progress.Style -eq [Windows.Forms.ProgressBarStyle]::Marquee) 'An active operation must use indeterminate progress.'
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not $operation.IsCompleted -and [DateTime]::UtcNow -lt $deadline) {
        [Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 20
    }
    Require $operation.IsCompleted ('The installer form operation timed out: '+$action)
    $null = $operation.GetAwaiter().GetResult()
    Require $selector.Enabled ('The language selector stayed disabled after '+$action+'.')
    Require ($progress.Value -eq 100) 'Successful completion must finish the progress indicator.'
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ftn-installer-languages-'+[guid]::NewGuid().ToString('N'))
$game = Join-Path $testRoot 'Synthetic Demo ä & English'
$null = New-Item -ItemType Directory -Path $game -Force
foreach ($name in @('FindTheNeedle.exe','FindTheNeedle.pck')) { [IO.File]::WriteAllBytes((Join-Path $game $name),[byte[]](1,2,3)) }
$form = $null
try {
    $form = New-SetupForm 'en-US'
    $directory = @(Get-FormControls $form | Where-Object { $_ -is [Windows.Forms.TextBox] })[0]
    $directory.Text = $game
    Require ($form.Text -eq 'FTN-Coop · Setup') 'Non-German Windows UI culture did not default to English.'
    Require-Caption $form 'Find The Needle · Co-op'
    Require-Caption $form 'Setup for the Steam demo V66 (Build 25963876).'
    Require-Caption $form 'Demo folder'
    Require-Caption $form 'Browse …'
    Require-Caption $form 'Install'
    Require-Caption $form 'Remove mod'
    Require-Caption $form 'Close the demo, then choose Install.'
    Require-Caption $form 'Language'
    $selector = @(Get-FormControls $form | Where-Object { $_ -is [Windows.Forms.ComboBox] })
    Require ($selector.Count -eq 1) 'The installer needs one visible language selector.'
    $selector = $selector[0]
    Require ($selector.Items.Count -eq 2 -and $selector.Items[0] -eq 'Deutsch' -and $selector.Items[1] -eq 'English') 'The language choices must be Deutsch and English.'
    $selector.SelectedIndex = 0
    Require ($form.Text -eq 'FTN-Koop · Installation') 'Choosing Deutsch did not translate the form title.'
    Require-Caption $form 'Find The Needle · Koop'
    Require-Caption $form 'Installation für die Steam-Demo V66 (Build 25963876).'
    Require-Caption $form 'Demo-Ordner'
    Require-Caption $form 'Ordner …'
    Require-Caption $form 'Installieren'
    Require-Caption $form 'Mod entfernen'
    Require-Caption $form 'Schließe die Demo, dann klicke auf Installieren.'
    Require-Caption $form 'Sprache'
    Require ($directory.Text -eq $game) 'Changing language lost the chosen demo folder.'
    $selector.SelectedIndex = 1
    Require-Caption $form 'Install'
    Require ($directory.Text -eq $game) 'Switching back to English lost the chosen demo folder.'

    # Run the real form operation against synthetic game files and its real embedded payload.
    $form.ShowInTaskbar = $false
    $form.StartPosition = [Windows.Forms.FormStartPosition]::Manual
    $form.Location = [Drawing.Point]::new(-30000,-30000)
    $form.Show()
    Complete-FormOperation $form $selector $directory 'Install'
    Require-Caption $form 'Installed. Start the demo through Steam and press F2 to open the co-op menu.'
    $selector.SelectedIndex = 0
    Require-Caption $form 'Installiert. Starte die Demo über Steam und öffne mit F2 das Koop-Menü.'

    $edited = Join-Path $game 'mods\ftn_coop\bootstrap.gd'
    Add-Content -LiteralPath $edited -Value '# language test local edit'
    foreach ($case in @(
        @{ Culture='de-DE'; Invalid='Wähle den Demo-Ordner mit FindTheNeedle.exe und FindTheNeedle.pck.'; Refusal='Eigene Änderungen an Mod-Dateien gefunden. Sichere sie vor dem Aktualisieren.' },
        @{ Culture='en-GB'; Invalid='Choose the demo folder containing FindTheNeedle.exe and FindTheNeedle.pck.'; Refusal='Local changes to mod files were found. Back them up before updating.' }
    )) {
        $invalid = Invoke-Install 'Install' $testRoot $case.Culture
        Require ($invalid.Code -ne 0 -and $invalid.Message -eq $case.Invalid) ('Invalid-folder guidance was not translated for '+$case.Culture)
        $refused = Invoke-Install 'Install' $game $case.Culture
        Require ($refused.Code -ne 0 -and $refused.Message -eq $case.Refusal) ('Local-edit refusal was not translated for '+$case.Culture)
    }
    $selector.SelectedIndex = 1
    Complete-FormOperation $form $selector $directory 'Remove'
    Require-Caption $form 'Mod removed. Your save files are kept. Locally edited mod files were kept.'
    $selector.SelectedIndex = 0
    Require-Caption $form 'Mod entfernt. Deine Spielstände bleiben erhalten. Lokal bearbeitete Mod-Dateien wurden behalten.'
    Require (Test-Path -LiteralPath $edited) 'Removal lost the locally edited file.'
    $form.Dispose()
    $form = New-SetupForm 'de-AT'
    Require ($form.Text -eq 'FTN-Koop · Installation') 'German Windows UI culture did not default to German.'
    $form.Dispose()
    $form = New-SetupForm 'fr-FR'
    Require ($form.Text -eq 'FTN-Coop · Setup') 'Other Windows UI cultures must default to English.'
    Write-Output 'PASS installer_language_defaults_switching_busy_state_and_localized_operations'
}
finally {
    if ($null -ne $form) { $form.Dispose() }
    # The test owns this freshly created absolute temporary directory only.
    $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
    $tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if ([IO.Path]::GetDirectoryName($resolvedRoot) -eq $tempParent -and [IO.Path]::GetFileName($resolvedRoot) -match '^ftn-installer-languages-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
    }
}
