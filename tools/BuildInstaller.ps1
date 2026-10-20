$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$frameworkRoot = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$compiler = Join-Path $frameworkRoot 'csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Windows .NET Framework compiler is missing.' }
& (Join-Path $PSScriptRoot 'Package.ps1')
$zip = Join-Path $projectRoot 'dist\FTN-Coop-0.6.1.zip'
$exe = Join-Path $projectRoot 'dist\FTN-Coop-0.6.1-Setup.exe'
$arguments = @('/nologo','/target:winexe','/platform:anycpu','/optimize+',
    ('/out:'+$exe),('/win32manifest:'+(Join-Path $projectRoot 'installer\app.manifest')),
    ('/resource:'+$zip+',FTNCoop.Payload.zip'),
    '/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll',
    ('/reference:'+(Join-Path $frameworkRoot 'System.IO.Compression.dll')),
    ('/reference:'+(Join-Path $frameworkRoot 'System.IO.Compression.FileSystem.dll')),
    (Join-Path $projectRoot 'installer\Program.cs'))
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'EXE compilation failed.' }
$hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($exe+'.sha256',$hash+'  FTN-Coop-0.6.1-Setup.exe'+[Environment]::NewLine)
Write-Output ('EXE erstellt: '+$exe)
