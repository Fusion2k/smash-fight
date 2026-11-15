param([string]$GodotPath, [switch]$Measure)
$ErrorActionPreference = 'Stop'
$prototypeRoot = $PSScriptRoot
if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) {
    foreach ($name in @('godot', 'godot4')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { $GodotPath = $command.Source; break }
    }
}
if (-not $GodotPath) {
    $locations = @("$env:SystemDrive/tools/Godot4", "$env:LOCALAPPDATA/Programs/Godot", "$env:ProgramFiles/Godot")
    foreach ($location in $locations) {
        $binary = Get-ChildItem -LiteralPath $location -Filter '*4.7.2*console.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($binary) { $GodotPath = $binary.FullName; break }
    }
}
if (-not $GodotPath) { throw 'Set GODOT_BIN or pass -GodotPath with a Godot 4.7.2 executable.' }
$engineVersion = & $GodotPath --version
if ($LASTEXITCODE -ne 0 -or $engineVersion -notmatch '^4\.7\.2\.stable') { throw "Expected Godot 4.7.2 stable; found $engineVersion" }
$arguments = @('--path', $prototypeRoot, 'res://chronology/lab.tscn', '--log-file', (Join-Path $prototypeRoot 'chronology/runtime.log'))
if ($Measure) { $arguments += @('--headless', '--', '--measure') }
& $GodotPath @arguments
exit $LASTEXITCODE
