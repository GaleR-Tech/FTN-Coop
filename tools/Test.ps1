param(
    [ValidateSet('all', 'collaboration_ui', 'rejoin', 'update_checker', 'presets', 'collaboration', 'shared_settings', 'mod_versions', 'localization', 'script_load', 'runtime_probe', 'game_adapter', 'input_bridge', 'session', 'protocol', 'snapshot_transfer', 'world_sync', 'loose_sync', 'network_controller', 'network_recovery', 'actor_lifecycle', 'local_transport', 'native_diagnostics', 'presence_ui', 'guest_movement', 'guest_controls', 'save_session', 'save_adapter')]
    [string]$Suite = 'all',
    [string]$TestScript = 'res://tests/runner.gd'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    throw 'Portable Godot 4.7.2 was not found in .tools/godot.'
}
$engineOutput = @(& $enginePath --headless --path $projectRoot --script $TestScript -- --suite $Suite 2>&1)
$engineExitCode = $LASTEXITCODE
$engineOutput | ForEach-Object { Write-Output ([string]$_) }
if ($engineExitCode -ne 0) { exit $engineExitCode }
# Godot may exit zero even when a GDScript callback aborts with an error.
if ($engineOutput | Select-String -Pattern 'SCRIPT ERROR:|^ERROR:|^FAIL ') { exit 1 }
exit 0
