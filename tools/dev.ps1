param(
    [Parameter(Position=0)][ValidateSet('check','editor','play','test','export')][string]$Action = 'check',
    [Parameter(Position=1)][ValidateSet('windows','linux')][string]$Target,
    [string]$GodotBin,
    [ValidateRange(1,86400)][int]$TimeoutSeconds = 120,
    [ValidateSet('normal','failure','engine-error','timeout')][string]$CheckCase = 'normal',
    [switch]$EditorSmoke
)
# Windows PowerShell 5.1 or PowerShell 7. No machine-specific engine paths.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$expectedVersion = '4.7.2.stable.official.ed1daf0bf'
$logDir = Join-Path $root ('build/logs/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $PID)
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $root 'build/.gdignore'),'',$utf8)

function Invoke-Bounded([string]$Name, [string[]]$Arguments, [switch]$LaunchOnly) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $script:engine
    # ProcessStartInfo.ArgumentList is unavailable on Windows PowerShell 5.1.
    $info.Arguments = ($Arguments | ForEach-Object {
        '"' + (($_ -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
    }) -join ' '
    $info.WorkingDirectory = $root
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = -not $LaunchOnly
    $info.RedirectStandardError = -not $LaunchOnly
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    [void]$process.Start()
    if ($LaunchOnly) {
        $message = "Started interactive editor PID $($process.Id); its lifetime is not limited by check timeouts."
        [IO.File]::WriteAllText((Join-Path $logDir "$Name.start.log"),$message,$utf8)
        Write-Host $message
        $process.Dispose()
        return ''
    }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        # Console engine wrappers may have a child executable. Kill the whole tree.
        if ($env:OS -eq 'Windows_NT') {
            $killer = Start-Process taskkill.exe -ArgumentList @('/PID',$process.Id,'/T','/F') -PassThru -WindowStyle Hidden
            if (-not $killer.WaitForExit(5000)) { $killer.Kill() }
            $killer.Dispose()
        } else { $process.Kill() }
        if (-not $process.WaitForExit(5000)) { throw "Cannot stop $Name; PID $($process.Id). Logs: $logDir" }
    }
    # Bound pipe drain as well (a child must not keep this wrapper waiting forever).
    $drained = [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout,$stderr),5000)
    $out = if ($stdout.IsCompleted) { $stdout.Result } else { '[stdout pipe did not close]' }
    $err = if ($stderr.IsCompleted) { $stderr.Result } else { '[stderr pipe did not close]' }
    [IO.File]::WriteAllText((Join-Path $logDir "$Name.stdout.log"),$out,$utf8)
    [IO.File]::WriteAllText((Join-Path $logDir "$Name.stderr.log"),$err,$utf8)
    Write-Host $out.TrimEnd()
    if ($err) { Write-Host $err.TrimEnd() }
    $code = $process.ExitCode
    $process.Dispose()
    if ($timedOut) { throw "$Name exceeded wall-clock timeout (${TimeoutSeconds}s). Logs: $logDir" }
    if (-not $drained) { throw "$Name output drain timed out. Logs: $logDir" }
    if ($code -ne 0) { throw "$Name exited $code. Logs: $logDir" }
    if (($out + $err) -match '(?m)(SCRIPT ERROR:|ERROR:)') { throw "$Name reported an engine/script error. Logs: $logDir" }
    return $out
}

try {
    if (-not $GodotBin) { $GodotBin = $env:GODOT_BIN }
    if (-not $GodotBin) { $GodotBin = 'godot' }
    $command = Get-Command $GodotBin -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { throw 'Godot not found. Install Standard Godot 4.7.2; pass -GodotBin <executable>, set GODOT_BIN, or add godot to PATH. See docs/development-workflow.md.' }
    $script:engine = $command.Source
    Write-Host "Engine: $engine"
    $version = (Invoke-Bounded 'version' @('--version')).Trim()
    if ($version -ne $expectedVersion) { throw "Wrong engine '$version'; required Standard $expectedVersion. Install the matching official Standard engine (not .NET)." }
    $commit = 'unknown'
    $oldCount = $env:GIT_CONFIG_COUNT
    try {
        $env:GIT_CONFIG_COUNT = '0'
        if (Test-Path (Join-Path $root '.git')) {
            $result = & git -c "safe.directory=$($root.Replace('\','/'))" -C $root rev-parse HEAD 2>$null
            if ($LASTEXITCODE -eq 0) { $commit = $result }
        }
    } catch { } finally { $env:GIT_CONFIG_COUNT = $oldCount }
    [IO.File]::WriteAllText((Join-Path $logDir 'run.json'),(@{source_commit=$commit;engine=$engine;version=$version;action=$Action;case=$CheckCase;timeout_seconds=$TimeoutSeconds} | ConvertTo-Json),$utf8)
    Write-Host "Source: $commit (working-tree changes may be present). Logs: $logDir"
    switch ($Action) {
        'check' {
            $null = Invoke-Bounded 'import' @('--headless','--path',$root,'--editor','--import')
            $result = Invoke-Bounded 'foundation' @('--headless','--path',$root,'--script','res://checks/foundation.gd','--',$CheckCase)
            if ($result -notmatch '(?m)^CHECKS_PASSED foundation\r?$') { throw 'Check runner did not report completion.' }
            Write-Host 'PASS: foundation checks only; gameplay/content/hardware acceptance is not delivered.'
        }
        'editor' {
            $editorArgs = @('--path',$root,'--editor')
            if ($EditorSmoke) { $editorArgs += @('--headless','--quit-after','2') }
            $null = Invoke-Bounded 'editor' $editorArgs -LaunchOnly:(-not $EditorSmoke)
        }
        default { throw "$Action is not implemented yet (application flow #18, exports #20). No playable build is claimed." }
    }
    exit 0
} catch {
    [IO.File]::WriteAllText((Join-Path $logDir 'failure.txt'),$_.ToString(),$utf8)
    Write-Host "FAIL: $_"
    Write-Host "Logs: $logDir"
    exit 1
}
