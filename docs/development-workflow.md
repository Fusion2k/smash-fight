# Development workflow

**Status: accepted specification for [#9](https://github.com/Fusion2k/smash-fight/issues/9), confirmed by the user on 2026-11-15; not an implemented launcher, export pipeline or check suite.** #8 has resolved GDScript and built-in GodotPhysics2D. The user accepted Compatibility, the logical layout/scaling policy, and the complete workflow below. Evidence comes from [#6 research](https://github.com/Fusion2k/smash-fight/blob/28981362e9541d704f6ffdf7fc4fff42bf6b3080/docs/research/godot-4-7-2-workflow.md), kept on its separate research branch.

## Portable setup contract

Use the Standard Godot 4.7.2 official distribution with GDScript and matching Standard 4.7.2 export templates. Windows x86_64 is the initial documented development host; native Linux x86_64 is the Steam Deck delivery target. Other development hosts can import source using their matching engine asset, but are not initially verified workflows. No .NET SDK is needed by this chosen project language.

A future repository launcher will resolve an explicit executable argument, then a machine-local `GODOT_BIN`, then `godot` on PATH. It will print the selected path and full version, reject a release other than `4.7.2.stable.official.ed1daf0bf`, and fail with useful setup instructions before import/run on a mismatch. `GODOT_BIN` is a project wrapper convention, not a Godot setting. No current PC installation path belongs in shared scripts. Download the official host archive and templates manually; automated engine downloads are unnecessary for this initial workflow. Record the download source and verify its published checksum when provisioning a new PC.

On a new Windows PC: install/extract that engine and matching templates, clone the repository, set local discovery, run the planned check command, then open the project through the planned editor command. The initial setup guide must include exact prerequisites and expected success output. A clean checkout must not require copying another PC's `.godot` cache.

## Planned command surface

These are accepted commands for future implementation, not files that currently exist. A PowerShell entry point exposes the actions below; small Windows `.cmd` wrappers may provide double-click Editor/Developer Test entry without duplicating discovery/version logic. Every action resolves the repository relative to the script, supports paths with spaces, stops on failure and returns a meaningful exit code.

| Planned invocation | Contract |
| --- | --- |
| `./tools/dev.ps1 check` | Validate engine, run a bounded headless import, content validation, and focused gameplay checks as they are implemented; retain logs and fail on assertions/timeouts. |
| `./tools/dev.ps1 editor` | Validate engine then open the root project in Godot's editor. |
| `./tools/dev.ps1 play` | Run the normal application scene with join/select/gamepad flow. |
| `./tools/dev.ps1 test` | Run the same application/Match through Developer Test: keyboard plus stationary opponent. |
| `./tools/dev.ps1 export windows` | Validate matching templates, import/check, then export the committed Windows x86_64 preset to ignored build output. |
| `./tools/dev.ps1 export linux` | Validate matching templates, import/check, then export the native Linux x86_64 preset to ignored build output. |

Use one shared bounded process runner with retained standard output/error and an external wall-clock timeout. Godot `--quit-after` limits iterations, not elapsed time. Check failures must be observable: verify the future test runner returns failure for an intentionally failing assertion. A successful import or parser run alone does not establish combat correctness.

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

Use Compatibility as the initial renderer on Windows and native Linux. Godot's [renderer overview](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html) identifies Compatibility as a suitable starting point for 2D; choosing it here is an accepted project decision, not measured proof of better Deck frame times. It keeps the first playable's simple 2D presentation within that renderer's feature set. Revisit it if a concrete visual feature or measured problem justifies the change. Remove incidental Forward Plus/D3D12 choices when implementing this confirmed policy; this specification changes no project settings.

Use a 1280 x 720 logical camera/HUD design area with `canvas_items`, fractional scaling and `keep` aspect. This is a logical layout, not a fixed 720p render buffer: [Godot's scaling guidance](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html) says canvas items draw at target resolution. At 1920 x 1080 the area fills the TV at 1.5x. On the Deck's [1280 x 800 display](https://www.steamdeck.com/en/tech) it leaves 40-pixel bars above and below. Preserve the same arena framing on all aspect ratios rather than revealing more stage on wider displays. World units, hitboxes and gameplay do not change with window size. This favors smooth placeholder/original 2D presentation; deliberate low-resolution pixel rendering would instead call for a different viewport policy. Actual UI readability, filtering and controller/TV presentation remain #10 checks.

For exports use separate executable and generated PCK together in each archive, with explicit character JSON inclusion. Godot's [Linux export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_linux.html) supports x86_64; its [export guidance](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html) describes inclusion filters for non-resource files such as JSON. The package layout is a reproducibility choice and must be checked by running the unpacked export. Neither renderer choice nor packaging documentation proves this game's performance or successful delivery.

## What is verified today

The source research checked the installed engine version/help and successfully imported the starter project headlessly in an isolated worktree, without tracked changes. Separate #11/#13 labs have their own version-checking Windows launchers and limited timing evidence. Main still has no gameplay scenes, main scene, production launcher, test suite or export presets. No production export, second-PC setup, native Deck/TV run, frame-rate target or complete match has passed. This accepted specification makes those future responsibilities concrete without counting them as delivered tooling.
