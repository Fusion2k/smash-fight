# Development workflow

**Status: accepted specification for [#9](https://github.com/Fusion2k/smash-fight/issues/9), confirmed by the user on 2026-11-15; #14 launcher/foundation checks, #15 catalog, #16 native movement, #17 integrated combat and #20 export-smoke tooling are implemented. Application/stock flow software is delivered in #18; physical hardware acceptance remains pending.** #8 has resolved GDScript and built-in GodotPhysics2D. The user accepted Compatibility, the logical layout/scaling policy, and the complete workflow below. Evidence comes from [#6 research](https://github.com/Fusion2k/smash-fight/blob/28981362e9541d704f6ffdf7fc4fff42bf6b3080/docs/research/godot-4-7-2-workflow.md), kept on its separate research branch.

## Portable setup contract

Use the Standard Godot 4.7.2 official distribution with GDScript and matching Standard 4.7.2 export templates. Windows x86_64 is the initial documented development host; native Linux x86_64 is the Steam Deck delivery target. Other development hosts can import source using their matching engine asset, but are not initially verified workflows. No .NET SDK is needed by this chosen project language.

The repository launcher resolves an explicit executable argument, then a machine-local `GODOT_BIN`, then `godot` on PATH. It prints the selected path and full version, rejects a release other than `4.7.2.stable.official.ed1daf0bf`, and fails with useful setup instructions before import/run on a mismatch. `GODOT_BIN` is a project wrapper convention, not a Godot setting. No current PC installation path belongs in shared scripts. Download the official host archive and templates manually; automated engine downloads are unnecessary for this initial workflow. Record the download source and verify its published checksum when provisioning a new PC.

On a new Windows PC: install/extract that engine and matching templates, clone the repository, set local discovery, run the check command, then open the project through the editor command. The initial setup guide must include exact prerequisites and expected success output. A clean checkout must not require copying another PC's `.godot` cache.

## Command surface

`tools/dev.ps1` supports Windows PowerShell 5.1 and PowerShell 7. `check`, `editor`, `play`, `test` and `export` are delivered. `play` launches the normal application; `test` or `play -DeveloperTest` launches keyboard Developer Test. Both return after starting a persistent interactive process. `export` now packages the real application. Every action resolves the repository relative to the script, supports paths with spaces, validates the engine and returns a meaningful exit code. Interactive editor launch returns after starting the editor; it does not terminate the editing session on the check timeout. `-EditorSmoke` instead uses bounded headless editor startup.

For a new Windows checkout, install/extract the official Standard engine, verify its published checksum, then run the following from the repository root (substitute your own local path). Windows PowerShell may require `powershell.exe -NoProfile -ExecutionPolicy Bypass -File` before the script path when downloaded scripts are blocked; this affects that process only.

```powershell
$env:GODOT_BIN = 'D:\Apps\Godot\Godot_v4.7.2-stable_win64_console.exe'
./tools/dev.ps1 check
./tools/dev.ps1 editor
```

Expected check completion includes `CHECKS_PASSED foundation`, `CHECKS_PASSED catalog (N checks)` and `PASS: foundation and catalog checks`. The foundation process also prints `CHECKS_PASSED movement (96 checks)`. This verifies engine/window configuration, production content and native Character movement. Complete gameplay and hardware acceptance remain upcoming. The launcher prints the selected executable, exact version, source HEAD (or unknown outside Git), and retained log directory. `-GodotBin <path>` overrides `GODOT_BIN`; without either it resolves `godot` on PATH. A copied `.godot` cache is unnecessary.

Bounded commands use `-TimeoutSeconds` (default 120 per process). Each retains stdout/stderr and `run.json` in ignored `build/logs/<run>/`; failure also writes `failure.txt`. Nonzero exit, Godot `ERROR:`/`SCRIPT ERROR:` output even with exit zero, missing completion, wall-clock timeout or output-drain timeout fails the wrapper. On Windows timeout terminates the engine process tree. The manifest records source HEAD; local modifications may be present, so milestone evidence must name its committed source. Build output is excluded from Godot import using a generated `.gdignore`.

To exercise failure propagation, run `check -CheckCase failure` (intentional assertion) and `check -CheckCase timeout -TimeoutSeconds 10` (intentional nontermination); both must return exit 1 with the corresponding failure log. `check -CheckCase engine-error` deliberately emits a Godot error and exits zero; the wrapper must still return 1. `editor -EditorSmoke` verifies bounded headless startup and exits. Use a wrong-version executable and a nonexistent explicit executable to verify discovery rejection. These commands are harness probes, not gameplay tests. Linux/PowerShell 7 execution, physical presentation and cross-PC provisioning remain unverified here; export evidence is recorded below.

| Invocation | Contract |
| --- | --- |
| `./tools/dev.ps1 check` | Delivered: validate engine, run bounded headless import and actual engine/window checks. Add content/gameplay checks as implemented; retain logs and fail on assertions/timeouts. |
| `./tools/dev.ps1 editor` | Validate engine then open the root project in Godot's editor. |
| `./tools/dev.ps1 play` | Run the normal application scene with join/select/gamepad flow. |
| `./tools/dev.ps1 test` | Run the same application/Match through Developer Test: keyboard plus stationary opponent. |
| `./tools/dev.ps1 export windows` | Validate matching templates, import/check, then export the committed Windows x86_64 preset to ignored build output. |
| `./tools/dev.ps1 export linux` | Validate matching templates, import/check, then export the native Linux x86_64 preset to ignored build output. |

Bounded commands use one shared process runner with retained standard output/error and an external wall-clock timeout. Godot `--quit-after` limits iterations, not elapsed time. Check failures must be observable: verify the test runner returns failure for an intentionally failing assertion. A successful import or parser run alone does not establish combat correctness.

## Git and build contents

Commit source, scenes/Resources, JSON, `project.godot`, `.import` metadata, `.uid` sidecars, tool scripts, engine contract and export presets. Rebuild/ignore `.godot/`; ignore build output and local executable settings. Keep export credentials outside Git. Export presets use relative destinations and explicit JSON inclusion so the catalog can read its referenced character files from `res://` in an exported build. Runtime saves/logs use `user://`; tuning remains a source-checkout workflow with a fresh validated snapshot on next match/test restart.

Generate two versioned development archives: Windows x86_64 and native Linux x86_64, each labeled with source commit, engine version, preset and build type. Include executable and all required game data together plus short run instructions. A recipient unpacks the complete archive. Steam storefront publishing, signing and an automatic deployment service are outside this first-playable setup decision.

## Steam Deck delivery and verification

The accepted initial transfer is manual: copy the complete Linux archive to the Deck using an available local transfer method or removable drive, unpack it, make its launcher executable as needed, and add the native executable as a non-Steam game. Run through Gaming Mode with the TV and external gamepads. A Windows export or Proton run does not establish native Linux acceptance. Keep transfer transport replaceable; it does not change game content or require stored network credentials.

Check the first runnable native build on actual Deck/TV early. Repeat after input, renderer/scaling, export, engine or significant performance changes and before declaring a playable milestone accepted. There is no daily hardware ritual when the change is a JSON damage edit. Exact playtest scenarios and performance measurement belong to #10, including later four-controller acceptance; steady 60 FPS remains the target and has not been demonstrated.

## Daily iteration

1. After source/content changes, run `check`; tune JSON and restart Developer Test or a match to load a fresh snapshot. Existing matches keep their prepared data.
2. Use Developer Test for movement, hit feedback and quick character edits; use normal application play for join/select, complete match, results/rematch and controller ownership changes.
3. Before a gameplay milestone, export and smoke-test Windows outside the editor. Run native Deck/TV checks at the triggers above. Keep evidence tied to source commit, build, hardware/display and controller configuration.
4. Review focused check output and source changes before committing. Meaningful automated assertions cover content validation, state isolation and the accepted Match/Character/combat interfaces; #10 defines the concrete acceptance set. Visual/game feel and hardware behavior need human playtests.

## Accepted renderer and presentation policy

Use Compatibility as the initial renderer on Windows and native Linux. Godot's [renderer overview](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html) identifies Compatibility as a suitable starting point for 2D; choosing it here is an accepted project decision, not measured proof of better Deck frame times. It keeps the first playable's simple 2D presentation within that renderer's feature set. Revisit it if a concrete visual feature or measured problem justifies the change. The incidental Forward Plus/D3D12 settings were replaced in #14.

Use a 1280 x 720 logical camera/HUD design area with `canvas_items`, fractional scaling and `keep` aspect. This is a logical layout, not a fixed 720p render buffer: [Godot's scaling guidance](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html) says canvas items draw at target resolution. At 1920 x 1080 the area fills the TV at 1.5x. On the Deck's [1280 x 800 display](https://www.steamdeck.com/en/tech) it leaves 40-pixel bars above and below. Preserve the same arena framing on all aspect ratios rather than revealing more stage on wider displays. World units, hitboxes and gameplay do not change with window size. This favors smooth placeholder/original 2D presentation; deliberate low-resolution pixel rendering would instead call for a different viewport policy. Actual UI readability, filtering and controller/TV presentation remain #10 checks.

For exports use separate executable and generated PCK together in each archive, with explicit character JSON inclusion. Godot's [Linux export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_linux.html) supports x86_64; its [export guidance](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html) describes inclusion filters for non-resource files such as JSON. The package layout is a reproducibility choice and must be checked by running the unpacked export. Neither renderer choice nor packaging documentation proves this game's performance or successful delivery.

## What is verified today

The source research checked the installed engine version/help and successfully imported the starter project headlessly in an isolated worktree, without tracked changes. Separate #11/#13 labs retain their limited timing evidence. Main has the #14 launcher/foundation runner, #15 Resources/catalog and #16 shared Character movement/first Arena with 96 native movement checks. The #20 export smoke adds a temporary main scene and committed presets; its separate-checkout Windows startup and native Linux build evidence is recorded below. Match chronology/shared attacks/hit resolution/local pause now have #17 integrated production checks ([evidence](evidence/17-chronological-combat.md)). Stock/application software is implemented in #18 with actual-interface automated fixtures. Physical complete matches, second-PC setup, native Deck/TV execution and the frame-rate target remain unverified. This accepted specification makes those responsibilities concrete without counting them as delivered behavior.

## Export smoke packages (#20)

Install the matching **Standard** templates manually from the [official 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable): download `Godot_v4.7.2-stable_export_templates.tpz` and `SHA512-SUMS.txt`, compare `Get-FileHash <tpz> -Algorithm SHA512` with its published line, then use the editor's Export Template Manager to install the TPZ. The Windows workflow expects `%APPDATA%/Godot/export_templates/4.7.2.stable/`. Keep `version.txt`, `windows_release_x86_64.exe`, `windows_release_x86_64_console.exe` and `linux_release.x86_64`; the full normal installation is also supported. Mono templates, other releases, renamed executables and partial/mismatched templates fail. `tools/export-templates.json` pins official release-template hashes derived from the checksum-verified TPZ. The wrapper does not download engines or templates.

Run `./tools/dev.ps1 export windows` and `./tools/dev.ps1 export linux` with the same discovery settings as `check`. Each action validates the exact engine, template version/header/architecture/SHA512, imports, runs the foundation/catalog checks, runs the prepared-content smoke and exports the committed release preset through the bounded runner. Nonzero exits, error output, missing completion or executable/PCK, and timeout fail with retained logs. Windows additionally unpacks its archive into a unique temporary path containing spaces outside the checkout and starts fresh release processes headlessly and graphically; both verify the packaged JSON through the production catalog. This graphical startup establishes startup only; no visual, physical-controller or frame-time gate is inferred.

Archives live under ignored `build/packages/`, named with project version, source commit, OS, architecture and release type. Each contains the separate executable/PCK, `manifest.json` (full source commit, dirty flag, engine, preset, type, template hash/source and build timestamp) and `RUN.txt`. Commit all source first and rebuild for a handoff whose manifest has `source_dirty: false`. Development exports may be dirty and their manifest explicitly says so. `build/logs/<run>/package.txt` identifies the archive; Windows `unpacked.txt` identifies the retained external smoke folder. Linux cross-export on Windows is a build check; it does not execute Linux.

The temporary main scene is explicitly **EXPORT SMOKE ONLY**: it prepares actual Zip/Bramble content, shows their authored static silhouettes, displays window/screen/controller diagnostics and reports raw buttons/axes/connections. Escape quits. It has no movement, combat, Match, menu flow or controller ownership. `--headless -- --verify-quit` checks bundled content/configuration and exits. Normal launch stays open for human display/input review. The later application must replace `run/main_scene`; do not treat this smoke as Developer Test or full game acceptance.

Transfer the complete Linux archive manually to the Deck, unpack, run `chmod +x ./smash-fight.x86_64`, and add that native executable as a non-Steam game. Run in Gaming Mode without Proton. Check 1920x1080/60 Hz TV and 1280x800 handheld framing/text plus intended external controller buttons/axes/disconnect/reconnect. Retain source/build, SteamOS/Deck/dock/TV/output/controller details, expected/actual observations and defects in #20. Hardware-unavailable checks stay unverified and #20 stays open. Final gameplay and H6/H7/H8 remain #21 responsibilities. See [export evidence](evidence/20-export-packages.md).

## Runnable application (#18)

The root main scene is now `app/app.tscn`. `play`, `test` and `play -DeveloperTest` validate the same portable engine discovery/version and launch persistent windows. The normal join screen offers Developer Test and keyboard-player entry; keyboard plus a pad uses normal independent selection/readiness. Complete controls and human check procedures are in [the #18 evidence](evidence/18-application-flow.md).

`check` now also requires `CHECKS_PASSED application (N checks)` after the existing foundation/movement/combat/catalog checks. The 60 Hz fixtures drive the real input parser, application commands and Match. Export source/unpacked verification expects `APPLICATION_CONTENT zip`, `APPLICATION_CONTENT bramble` and `APPLICATION_START_PASSED`; the archived `smoke/export_smoke.tscn` remains explicitly launchable for raw hardware debugging using `godot --path . res://smoke/export_smoke.tscn`.

Bounded application verification uses `-- --verify-quit` (12 physics ticks). For real rendered inspection, use `-- --developer-test --verify-quit --verify-steps=240 --capture=<absolute.png>`. Optional `--capture-phase=paused` pauses at the capture tick; `--capture-phase=results` uses a clearly developer-only reproducible final-stock draw setup through Match. These flags are separate from normal interactive lifetimes. Startup/capture does not establish real-device behavior or human visual/feel acceptance.
