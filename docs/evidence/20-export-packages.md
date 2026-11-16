# Export packages and early hardware smoke (#20)

Status: implementation checkpoint; #20 remains open until actual native Deck/TV/controller smoke. Smoke-only coverage must be replaced by gameplay in #21.

The implementation adds pinned Standard Godot 4.7.2 Windows/native Linux x86_64 release presets, explicit `characters/**/*.json` inclusion, separate executable/PCK archives, manifest/run instructions, and a minimal runnable prepared-content/display/raw-input smoke main scene. The portable launcher retains its bounded process/error/log contract for import, checks, export and fresh unpacked Windows launches. No engine/template downloader is shipped.

## Provisioning provenance

Official source: [Godot 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable). The Standard `Godot_v4.7.2-stable_export_templates.tpz` was downloaded and its SHA512 matched the corresponding published `SHA512-SUMS.txt` line:

`ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079`

Only required version/release files were installed on this Windows machine. `tools/export-templates.json` records individual executable hashes from that verified TPZ. The wrapper verifies the template version file, PE/ELF x86_64 header, pinned SHA512 and Windows console companion. Exact editor contract: `4.7.2.stable.official.ed1daf0bf`. Compatibility, logical 1280x720, fractional `canvas_items`, keep aspect. No credentials or machine installation paths are committed.

## Named checks and interpretation

| Check | Expected / actual |
| --- | --- |
| Missing matching templates | Before installation, `export windows` exits 1 before import/export and prints exact manual setup guidance; retained `build/logs/20261115-190954-310-27064/failure.txt`. |
| Foundation | Seven actual engine/window configuration checks pass. |
| Catalog | All 60 production content/snapshot checks pass. Expected nonfinite-data warning is retained. |
| Source smoke | Actual catalog prepares Zip and Bramble, reads JSON and instantiates detached authored scenes; completion passes. |
| Windows release export | Matching official release template, separate PE executable/PCK; both character JSON files appear in export output. |
| Unpacked content | Fresh release executable process in a unique temporary folder containing spaces outside the checkout must print both `EXPORT_CONTENT` lines and `EXPORT_SMOKE_PASSED ... exported=true`. This uses bundled PCK JSON, without a source path argument. |
| Windows graphical startup | Fresh unpacked release process must initialize the actual Windows display/Compatibility renderer and print smoke completion; exits via `--verify-quit`. No screenshot or human visual acceptance is claimed. |
| Native Linux release | Cross-export from Windows produces native ELF x86_64 plus PCK; not executed on Windows and no native runtime acceptance inferred. |

During development, import correctly failed on accidentally ANSI-encoded smoke source; files were corrected to UTF-8. The unpacked completion check also correctly failed when its diagnostic used an obsolete feature tag; changed to the documented `template` tag. These failure traces remain in ignored build/logs. Final handoff issue evidence names the clean committed source and final build logs/archive hashes. Each archive independently carries full source commit, dirty status, exact engine, preset, architecture, release type, template provenance and timestamp; final handoff requires `source_dirty=false`.

## Pending human evidence

Actual Steam Deck/SteamOS hardware, dock/1080p TV, handheld display and intended external gamepads are unavailable to this agent. No Deck native launch, Gaming Mode, TV/handheld framing/readability, physical button/axis/disconnect/reconnect or performance check passed. Transfer the complete Linux archive, unpack, chmod the native launcher, add it as a non-Steam game without Proton, and record the #20 early smoke scenario from RUN.txt. Keep #20 open until that evidence is supplied. H6 second Windows PC and all full-game H1-H8/60 FPS acceptance remain #21 work.

Official API/CLI references: [command line](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html), [export inclusion/presets](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html), [template feature tag](https://docs.godotengine.org/en/4.7/tutorials/export/feature_tags.html). The smoke is a platform probe, not the normal application or Developer Test; `play`/`test` still fail clearly until #18. The normal application should replace `project.godot`'s smoke main scene when ready.