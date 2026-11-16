# Dot-sourced by dev.ps1 after exact engine validation. Uses its bounded runner/logs.
if (-not $Target) { throw 'Choose export windows or export linux.' }
if ($commit -eq 'unknown') { throw 'Exports require Git and an identifiable source commit. Export from a source checkout.' }
$templateRoot = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Godot/export_templates/4.7.2.stable'
$versionFile = Join-Path $templateRoot 'version.txt'
if (-not (Test-Path $versionFile) -or (Get-Content $versionFile -Raw).Trim() -ne '4.7.2.stable') {
    throw "Matching Standard 4.7.2 templates missing/invalid at $templateRoot. Manually install the official Godot_v4.7.2-stable_export_templates.tpz using the editor template manager; verify SHA512-SUMS.txt from the official release. See docs/development-workflow.md."
}
$templateName = if ($Target -eq 'windows') { 'windows_release_x86_64.exe' } else { 'linux_release.x86_64' }
$template = Join-Path $templateRoot $templateName
if (-not (Test-Path $template) -or (Get-Item $template).Length -lt 1000000) { throw "Missing/invalid Standard release template: $template" }
$header = [IO.File]::OpenRead($template)
try {
    $bytes = New-Object byte[] 64
    [void]$header.Read($bytes,0,64)
    if ($Target -eq 'windows') {
        if ($bytes[0] -ne 77 -or $bytes[1] -ne 90) { throw 'Windows template must be a PE executable.' }
        $header.Position = [BitConverter]::ToInt32($bytes,60)
        $pe = New-Object byte[] 6
        [void]$header.Read($pe,0,6)
        if ([BitConverter]::ToUInt32($pe,0) -ne 17744 -or [BitConverter]::ToUInt16($pe,4) -ne 34404) { throw 'Windows template must be PE x86_64.' }
    } elseif ($bytes[0] -ne 127 -or $bytes[1] -ne 69 -or $bytes[2] -ne 76 -or $bytes[3] -ne 70 -or $bytes[4] -ne 2 -or $bytes[5] -ne 1 -or [BitConverter]::ToUInt16($bytes,18) -ne 62) { throw 'Linux template must be little-endian ELF x86_64.' }
} finally { $header.Dispose() }
$contract = Get-Content (Join-Path $PSScriptRoot 'export-templates.json') -Raw | ConvertFrom-Json
$requiredTemplates = @($templateName)
if ($Target -eq 'windows') { $requiredTemplates += 'windows_release_x86_64_console.exe' }
foreach ($name in $requiredTemplates) {
    $file = Join-Path $templateRoot $name
    if (-not (Test-Path $file) -or (Get-FileHash $file -Algorithm SHA512).Hash.ToLower() -ne $contract.files.$name) {
        throw "Template checksum mismatch/missing: $file. Reinstall the matching official Standard templates; see docs/development-workflow.md."
    }
}
Write-Host "Templates: $templateRoot ($templateName), pinned official SHA512 verified"
$null = Invoke-Bounded 'import' @('--headless','--path',$root,'--editor','--import')
foreach ($suite in @('foundation','catalog')) {
    $result = Invoke-Bounded $suite @('--headless','--path',$root,'--script',"res://checks/$suite.gd")
    if ($result -notmatch "(?m)^CHECKS_PASSED $suite(?: \(\d+ checks\))?\r?`$") { throw "$suite did not report completion." }
}
$smoke = Invoke-Bounded 'source-smoke' @('--headless','--path',$root,'--','--verify-quit')
if ($smoke -notmatch 'EXPORT_SMOKE_PASSED') { throw 'Source smoke did not report completion.' }
$projectVersion = (Select-String -Path (Join-Path $root 'project.godot') -Pattern '^config/version="([^"]+)"').Matches.Groups[1].Value
if (-not $projectVersion -or $projectVersion -notmatch '^[a-zA-Z0-9._-]+$') { throw 'Set a filename-safe project config/version before packaging.' }
$shortCommit = $commit.Substring(0,[Math]::Min(12,$commit.Length))
$packageName = "smash-fight-$projectVersion-$shortCommit-$Target-x86_64-release"
if ($sourceDirty) { $packageName += '-dirty' }
$packageDir = Join-Path $root ("build/packages/$packageName/" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory $packageDir -Force | Out-Null
$preset = if ($Target -eq 'windows') { 'Windows x86_64' } else { 'Linux x86_64' }
$executable = if ($Target -eq 'windows') { 'smash-fight.exe' } else { 'smash-fight.x86_64' }
$destination = Join-Path $packageDir $executable
$null = Invoke-Bounded 'export' @('--headless','--path',$root,'--export-release',$preset,$destination)
foreach ($required in @($destination,(Join-Path $packageDir 'smash-fight.pck'))) {
    if (-not (Test-Path $required) -or (Get-Item $required).Length -eq 0) { throw "Export did not create $required" }
}
$manifest = [ordered]@{project_version=$projectVersion;source_commit=$commit;engine_version=$version;preset=$preset;architecture='x86_64';build_type='release';template_source=$contract.source;coverage='export smoke only; gameplay and hardware unverified';template_sha512=(Get-FileHash $template -Algorithm SHA512).Hash;built_utc=[DateTime]::UtcNow.ToString('o');source_dirty=$sourceDirty}
[IO.File]::WriteAllText((Join-Path $packageDir 'manifest.json'),($manifest | ConvertTo-Json),$utf8)
$instructions = @"
Smash Fight $projectVersion - EXPORT SMOKE ONLY
Keep every file together. This probe shows prepared Zip/Bramble content, display and raw controller events; it is not the game or its player ownership flow.
Windows: double-click smash-fight.exe. Escape quits.
Linux/Steam Deck: unpack the entire archive; run chmod +x ./smash-fight.x86_64 then ./smash-fight.x86_64. Add that native executable as a non-Steam game; do not select Proton compatibility.
Paths containing spaces: in a terminal change directory to the unpacked folder using shell quoting, then use the relative commands above.
Machine check: Windows .\smash-fight.exe --headless -- --verify-quit ; Linux ./smash-fight.x86_64 --headless -- --verify-quit
Expected: EXPORT_CONTENT zip, EXPORT_CONTENT bramble and EXPORT_SMOKE_PASSED. Raw JSON is packaged inside smash-fight.pck.
Physical review: Gaming Mode, 1080p TV at 60 Hz plus 1280x800 handheld; verify readable text/16:9 bars, both characters, pad buttons/axes and connection events. Record OS/dock/pads/output/renderer/source/build and failures in issue #20. This does not establish gameplay, ownership, feel or 60 FPS acceptance.
Runtime Godot logs use user:// (the OS user-data directory), not this folder.
"@
[IO.File]::WriteAllText((Join-Path $packageDir 'RUN.txt'),$instructions,$utf8)
$archive = Join-Path (Split-Path $packageDir -Parent) "$packageName.zip"
Compress-Archive -Path (Join-Path $packageDir '*') -DestinationPath $archive -CompressionLevel Optimal -Force
if ($Target -eq 'windows') {
    # A separate fresh process outside the checkout prevents source res:// fallback.
    $unpacked = Join-Path ([IO.Path]::GetTempPath()) ("Smash Fight unpacked " + [Guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
    $result = Invoke-Bounded 'unpacked-smoke' @('--headless','--','--verify-quit') -Executable (Join-Path $unpacked $executable) -WorkingDirectory $unpacked
    if ($result -notmatch 'EXPORT_SMOKE_PASSED .*exported=true' -or $result -notmatch 'EXPORT_CONTENT zip' -or $result -notmatch 'EXPORT_CONTENT bramble') { throw 'Unpacked export did not verify bundled content.' }
    $windowed = Invoke-Bounded 'unpacked-window-smoke' @('--','--verify-quit') -Executable (Join-Path $unpacked $executable) -WorkingDirectory $unpacked
    if ($windowed -notmatch 'EXPORT_SMOKE_PASSED .*display=windows') { throw 'Unpacked graphical Windows startup did not report completion.' }
    [IO.File]::WriteAllText((Join-Path $logDir 'unpacked.txt'),$unpacked,$utf8)
    Write-Host "UNPACKED_SMOKE_PASSED: $unpacked"
}
[IO.File]::WriteAllText((Join-Path $logDir 'package.txt'),$archive,$utf8)
Write-Host "PACKAGE: $archive"
Write-Host 'PASS: release package created; see retained logs for Windows unpacked startup. Physical hardware acceptance remains unverified.'
