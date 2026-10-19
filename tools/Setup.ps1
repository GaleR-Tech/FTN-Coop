param(
    [ValidateSet('Install','Remove')][string]$Action = 'Install',
    [string]$GameDir = '',
    [switch]$NonInteractive,
    [ValidateSet('auto','de','en')][string]$Language = 'auto'
)
$ErrorActionPreference = 'Stop'
if ($Language -eq 'auto') { $Language = if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'de') { 'de' } else { 'en' } }
function Ftn-Text([string]$German, [string]$English) { if ($Language -eq 'de') { $German } else { $English } }
try {
    if (-not $GameDir) {
        $steamRoots = @()
        foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
            $settings = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
            if ($settings) {
                if ($settings.SteamPath) { $steamRoots += $settings.SteamPath }
                if ($settings.InstallPath) { $steamRoots += $settings.InstallPath }
            }
        }
        $libraries = @($steamRoots)
        foreach ($steamRoot in $steamRoots) {
            $libraryFile = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
            if (Test-Path -LiteralPath $libraryFile) {
                $libraryText = [IO.File]::ReadAllText($libraryFile)
                foreach ($match in [regex]::Matches($libraryText,'"path"\s+"([^"]+)"')) {
                    $libraries += $match.Groups[1].Value.Replace('\\','\')
                }
            }
        }
        foreach ($library in @($libraries | Select-Object -Unique)) {
            $candidate = Join-Path $library 'steamapps\common\Find The Needle Demo'
            if ((Test-Path -LiteralPath (Join-Path $candidate 'FindTheNeedle.exe')) -and (Test-Path -LiteralPath (Join-Path $candidate 'FindTheNeedle.pck'))) {
                $GameDir = $candidate
                break
            }
        }
    }
    if (-not $GameDir) {
        if ($NonInteractive) { throw (Ftn-Text 'Demo-Ordner nicht automatisch gefunden.' 'The demo folder could not be found automatically.') }
        Write-Host (Ftn-Text 'In Steam: Demo > Eigenschaften > Installierte Dateien > Durchsuchen.' 'In Steam: Demo > Properties > Installed Files > Browse.')
        $GameDir = (Read-Host (Ftn-Text 'Den vollstaendigen Demo-Ordner hier einfuegen' 'Paste the full demo folder path here')).Trim().Trim('"')
    }
    $scriptName = if ($Action -eq 'Install') { 'Install.ps1' } else { 'Uninstall.ps1' }
    & (Join-Path $PSScriptRoot $scriptName) -GameDir $GameDir -Language $Language
    exit 0
}
catch {
    Write-Host ((Ftn-Text 'Fehler: ' 'Error: ')+$_.Exception.Message) -ForegroundColor Red
    Write-Host (Ftn-Text 'Das Spiel muss geschlossen sein. Details stehen in README.de.md.' 'The game must be closed. See README.en.md for details.')
    exit 1
}
