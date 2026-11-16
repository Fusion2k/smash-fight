param([switch]$Trace)

$ErrorActionPreference = 'Stop'
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'D:\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $godot)) {
    throw "Godot 4.7.2 console executable not found: $godot. Set GODOT_BIN."
}

# Register global classes (Character, HitDetection) in a fresh checkout before
# running a --script, which does not perform an editor import itself.
& $godot --headless --path $projectRoot --editor --quit | Out-Null

if ($Trace) {
    & $godot --headless --path $projectRoot --script res://prototype/animation_moves/lab_trace.gd
} else {
    & $godot --path $projectRoot res://prototype/animation_moves/animation_moves_lab.tscn
}
