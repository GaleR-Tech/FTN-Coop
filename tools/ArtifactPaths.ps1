function Get-FtnArtifactPaths {
    param([Parameter(Mandatory=$true)][string]$ProjectRoot)
    $versionMatch = [regex]::Match([IO.File]::ReadAllText((Join-Path $ProjectRoot 'mods/ftn_coop/bootstrap.gd')), '(?m)^const VERSION := "([0-9]+\.[0-9]+\.[0-9]+)"\r?$')
    if (-not $versionMatch.Success) { throw 'PACKAGE_VERSION_INVALID' }
    $version = $versionMatch.Groups[1].Value
    $series = ($version.Split('.')[0..1] -join '.')
    $directory = Join-Path $ProjectRoot ('dist/'+$series+'/'+$version)
    [pscustomobject]@{
        Version = $version
        Directory = $directory
        Zip = Join-Path $directory ('FTN-Coop-'+$version+'.zip')
        Windows = Join-Path $directory ('FTN-Coop-'+$version+'-Setup.exe')
        Linux = Join-Path $directory ('FTN-Coop-'+$version+'-Linux.run')
    }
}
