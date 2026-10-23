$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'ArtifactPaths.ps1')
$artifacts = Get-FtnArtifactPaths -ProjectRoot $projectRoot
& (Join-Path $PSScriptRoot 'Package.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$output = $artifacts.Linux
$temporary = $output+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
$inputZip = [IO.Compression.ZipFile]::OpenRead($artifacts.Zip)
try {
    $buffer = [IO.MemoryStream]::new()
    $archive = [IO.Compression.ZipArchive]::new($buffer,[IO.Compression.ZipArchiveMode]::Create,$true)
    try {
        foreach ($entry in $inputZip.Entries) {
            if ($entry.FullName -notmatch '^mods/ftn_coop/[a-z_]+\.gd$' -and $entry.FullName -notin @('README.md','README.en.md','README.de.md','LICENSE','LICENSE.en.txt','THIRD_PARTY_NOTICES.txt')) { continue }
            $target = $archive.CreateEntry($entry.FullName,[IO.Compression.CompressionLevel]::Optimal)
            $sourceStream = $entry.Open()
            $targetStream = $target.Open()
            try { $sourceStream.CopyTo($targetStream) } finally { $sourceStream.Dispose(); $targetStream.Dispose() }
        }
        foreach ($mapping in @(@('linux_main.py','__main__.py'),@('linux_core.py','linux_core.py'),@('linux_setup.py','linux_setup.py'))) {
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $projectRoot ('installer\'+$mapping[0])),$mapping[1],[IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $archive.Dispose() }
    $file = [IO.File]::Create($temporary)
    try {
        $header = [Text.Encoding]::ASCII.GetBytes("#!/usr/bin/env python3`n")
        $file.Write($header,0,$header.Length)
        $buffer.Position = 0
        $buffer.CopyTo($file)
    } finally { $file.Dispose(); $buffer.Dispose() }
    Move-Item -LiteralPath $temporary -Destination $output -Force
} finally {
    $inputZip.Dispose()
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
}
$hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($output+'.sha256',$hash+'  '+[IO.Path]::GetFileName($output)+[Environment]::NewLine)
Write-Output ('Linux installer: '+$output)
