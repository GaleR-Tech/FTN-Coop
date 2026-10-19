param(
    [ValidateSet('Install','Remove')][string]$Action = 'Install',
    [string]$GameDir = '',
    [switch]$NonInteractive
)
$ErrorActionPreference = 'Stop'
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
        if ($NonInteractive) { throw 'Demo-Ordner nicht automatisch gefunden.' }
        Write-Host 'In Steam: Demo > Eigenschaften > Installierte Dateien > Durchsuchen.'
        $GameDir = (Read-Host 'Den vollstaendigen Demo-Ordner hier einfuegen').Trim().Trim('"')
    }
    $scriptName = if ($Action -eq 'Install') { 'Install.ps1' } else { 'Uninstall.ps1' }
    & (Join-Path $PSScriptRoot $scriptName) -GameDir $GameDir
    exit 0
}
catch {
    Write-Host ('Fehler: '+$_.Exception.Message) -ForegroundColor Red
    Write-Host 'Das Spiel muss geschlossen sein. Details stehen in README.md.'
    exit 1
}
