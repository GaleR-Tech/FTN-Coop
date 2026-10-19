param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $SourceRoot).ProviderPath
$files = @(git -C $root ls-files)
if ($LASTEXITCODE -ne 0 -or $files.Count -eq 0) { throw 'Cannot read Git publication file list.' }
$exact = @('.gitignore','.github/FUNDING.yml','CHANGELOG.md','README.md','README.en.md','README.de.md',
    'LICENSE','LICENSE.en.txt','THIRD_PARTY_NOTICES.txt','project.godot',
    'Install.cmd','Remove.cmd','Installieren.cmd','Entfernen.cmd',
    'docs/playtest-checklist.md','docs/playtest-checklist.en.md','installer/Program.cs','installer/app.manifest')
$utf8 = [Text.UTF8Encoding]::new($false,$true)
foreach ($file in $files) {
    $allowed = $file -cin $exact -or $file -cmatch '^mods/ftn_coop/[a-z_]+\.gd$' -or
        $file -cmatch '^tests/(fixtures/)?[a-z0-9_]+\.(gd|tscn|ps1)$' -or $file -cmatch '^tools/[A-Za-z]+\.ps1$'
    if (-not $allowed) { throw ('PUBLICATION_FILE_NOT_ALLOWED: '+$file) }
    $path = Join-Path $root $file
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -gt 1048576) { throw ('PUBLICATION_FILE_TOO_LARGE: '+$file) }
    $content = $utf8.GetString($bytes)
    if ($content.Contains([string][char]0)) { throw ('PUBLICATION_BINARY_FILE: '+$file) }
    if ($content -match 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----') {
        throw ('PUBLICATION_SECRET_PATTERN: '+$file)
    }
    # These two exact strings are synthetic privacy-test inputs, not local paths.
    if ($file -ceq 'tests/test_presence_ui.gd') {
        $content = $content.Replace(('C:/'+'Users/SECRET'),'').Replace('C:/secret','')
    }
    if ($content -match '[A-Z]:[/\\]Users[/\\]|\\\\[n]as-[^\s"'']+|marco\.franke') { throw ('PUBLICATION_PRIVATE_PATH: '+$file) }
}
Write-Output ('PASS publication_file_allowlist_and_content ('+$files.Count+' text files)')
